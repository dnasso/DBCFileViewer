#include <iostream>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <unistd.h>
#include <string.h>

int main() {
    const char* server_ip = "146.163.50.202";
    int server_port = 8828;
    
    std::cout << "Attempting to connect to " << server_ip << ":" << server_port << std::endl;
    
    // Create socket
    int sock = socket(AF_INET, SOCK_STREAM, 0);
    if (sock < 0) {
        std::cerr << "Failed to create socket" << std::endl;
        return 1;
    }
    
    // Set up server address
    struct sockaddr_in server_addr;
    server_addr.sin_family = AF_INET;
    server_addr.sin_port = htons(server_port);
    
    if (inet_pton(AF_INET, server_ip, &server_addr.sin_addr) <= 0) {
        std::cerr << "Invalid address" << std::endl;
        close(sock);
        return 1;
    }
    
    // Connect to server
    if (connect(sock, (struct sockaddr*)&server_addr, sizeof(server_addr)) < 0) {
        std::cerr << "Connection failed" << std::endl;
        close(sock);
        return 1;
    }
    
    std::cout << "Successfully connected to server!" << std::endl;
    
    // Send a test message
    const char* test_message = "0x123#01 02 03 04 05 06 07 08#100";
    if (send(sock, test_message, strlen(test_message), 0) < 0) {
        std::cerr << "Failed to send message" << std::endl;
    } else {
        std::cout << "Sent test message: " << test_message << std::endl;
    }
    
    // Close connection
    close(sock);
    std::cout << "Connection closed" << std::endl;
    
    return 0;
}
