/*
 * DBC RECEIVER/SERVER
 * ------------------
 * Author: Thoshitha Gamage
 * Date: 01/29/2025
 * License: MIT License
 * Description: This is a receiver that acts as a server for CAN messages from DBC Sender.
 */

#include <iostream>
#include <fstream>
#include <string>
#include <cstring>
#include <sys/types.h>
#include <sys/socket.h>
#include <netdb.h>
#include <unistd.h>
#include <arpa/inet.h>
#include <thread>
#include <vector>

constexpr size_t MAXDATASIZE = 10000;

// Helper function to trim whitespace and invisible characters from string
std::string trim(const std::string& str) {
    size_t first = str.find_first_not_of(" \t\r\n\f\v");
    if (first == std::string::npos) return "";
    size_t last = str.find_last_not_of(" \t\r\n\f\v");
    return str.substr(first, last - first + 1);
}

// Get sockaddr, IPv4 or IPv6
void* get_in_addr(struct sockaddr* sa) {
    if (sa->sa_family == AF_INET) {
        return &(((struct sockaddr_in*)sa)->sin_addr);
    }
    return &(((struct sockaddr_in6*)sa)->sin6_addr);
}

// Handle client connection in a separate thread
void handleClient(int client_fd, const std::string& client_ip) {
    std::cout << "Client connected from " << client_ip << std::endl;
    
    char buffer[MAXDATASIZE];
    while (true) {
        int bytes_read = recv(client_fd, buffer, sizeof(buffer) - 1, 0);
        if (bytes_read <= 0) {
            std::cout << "Client " << client_ip << " disconnected" << std::endl;
            break;
        }
        
        buffer[bytes_read] = '\0';
        std::string message(buffer);
        
        // Log the received CAN message
        std::cout << "Received CAN message from " << client_ip << ": " << message << std::endl;
        
        // Parse and display the message format (expecting # as delimiter)
        size_t first_delimiter = message.find('#');
        if (first_delimiter != std::string::npos) {
            std::string can_id = message.substr(0, first_delimiter);
            std::string remaining = message.substr(first_delimiter + 1);
            
            // Check if there's a second delimiter for rate
            size_t second_delimiter = remaining.find('#');
            if (second_delimiter != std::string::npos) {
                std::string data = remaining.substr(0, second_delimiter);
                std::string rate = remaining.substr(second_delimiter + 1);
                
                std::cout << "  -> CAN ID: " << can_id << std::endl;
                std::cout << "  -> Data: " << data << std::endl;
                std::cout << "  -> Rate: " << rate << " ms" << std::endl;
            } else {
                // No rate provided, just CAN_ID#DATA format
                std::string data = remaining;
                
                std::cout << "  -> CAN ID: " << can_id << std::endl;
                std::cout << "  -> Data: " << data << std::endl;
                std::cout << "  -> Rate: Not specified" << std::endl;
            }
        } else {
            std::cout << "  -> Raw message: " << message << std::endl;
        }
        std::cout << "----------------------------------------" << std::endl;
        
        // Send acknowledgment back to sender
        std::string ack = "Message received: " + message;
        send(client_fd, ack.c_str(), ack.length(), 0);
    }
    
    close(client_fd);
}

int main(int argc, char* argv[]) {
    if (argc != 2) {
        std::cerr << "usage: receiver client.conf\n";
        return 1;
    }

    // Read configuration from file
    std::string serverIP, serverPort;
    bool hasServerIP = false, hasServerPort = false;

    std::ifstream configFile(argv[1]);
    if (!configFile.is_open()) {
        std::cerr << "Error opening config file: " << argv[1] << std::endl;
        return 1;
    }

    std::string line;
    while (std::getline(configFile, line)) {
        if (line.find("SERVER_IP=") == 0) {
            serverIP = trim(line.substr(10));
            hasServerIP = true;
        } else if (line.find("SERVER_PORT=") == 0) {
            serverPort = trim(line.substr(12));
            hasServerPort = true;
        }
    }
    configFile.close();

    if (!hasServerIP || !hasServerPort) {
        std::cerr << "Invalid config file format.\n";
        return 1;
    }

    std::cout << "=== DBC CAN Message Receiver ===" << std::endl;
    std::cout << "Starting server on " << serverIP << ":" << serverPort << std::endl;
    std::cout << "Expected message format: CAN_ID#DATA#RATE" << std::endl;
    std::cout << "Press Ctrl+C to stop the server" << std::endl;
    std::cout << "===============================" << std::endl;

    // Create socket
    int server_fd = socket(AF_INET, SOCK_STREAM, 0);
    if (server_fd == -1) {
        std::cerr << "Failed to create socket" << std::endl;
        return 1;
    }

    // Allow socket reuse
    int opt = 1;
    if (setsockopt(server_fd, SOL_SOCKET, SO_REUSEADDR, &opt, sizeof(opt)) < 0) {
        std::cerr << "Failed to set socket options" << std::endl;
        close(server_fd);
        return 1;
    }

    // Set up server address
    struct sockaddr_in address;
    address.sin_family = AF_INET;
    address.sin_port = htons(std::stoi(serverPort));
    
    // Bind to specific IP or any interface
    if (serverIP == "0.0.0.0" || serverIP == "127.0.0.1") {
        address.sin_addr.s_addr = (serverIP == "0.0.0.0") ? INADDR_ANY : inet_addr("127.0.0.1");
    } else {
        address.sin_addr.s_addr = inet_addr(serverIP.c_str());
    }

    // Bind socket
    if (bind(server_fd, (struct sockaddr*)&address, sizeof(address)) < 0) {
        std::cerr << "Failed to bind socket to " << serverIP << ":" << serverPort << std::endl;
        close(server_fd);
        return 1;
    }

    // Listen for connections
    if (listen(server_fd, 5) < 0) {
        std::cerr << "Failed to listen on socket" << std::endl;
        close(server_fd);
        return 1;
    }

    std::cout << "Server listening on " << serverIP << ":" << serverPort << std::endl;
    std::cout << "Waiting for DBC Sender connections..." << std::endl;

    // Accept connections in a loop
    while (true) {
        struct sockaddr_in client_addr;
        socklen_t client_len = sizeof(client_addr);
        
        int client_fd = accept(server_fd, (struct sockaddr*)&client_addr, &client_len);
        if (client_fd < 0) {
            std::cerr << "Failed to accept connection" << std::endl;
            continue;
        }
        
        // Get client IP address
        char client_ip[INET_ADDRSTRLEN];
        inet_ntop(AF_INET, &(client_addr.sin_addr), client_ip, INET_ADDRSTRLEN);
        
        // Handle client in a separate thread
        std::thread client_thread(handleClient, client_fd, std::string(client_ip));
        client_thread.detach();
    }

    close(server_fd);
    return 0;
}
