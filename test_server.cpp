#include <iostream>
#include <string>
#include <thread>
#include <vector>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <unistd.h>
#include <cstring>

class SimpleCANServer {
private:
    int server_fd;
    int port;
    bool running;
    
public:
    SimpleCANServer(int p = 12345) : port(p), running(false) {}
    
    ~SimpleCANServer() {
        stop();
    }
    
    bool start() {
        server_fd = socket(AF_INET, SOCK_STREAM, 0);
        if (server_fd == -1) {
            std::cerr << "Failed to create socket" << std::endl;
            return false;
        }
        
        // Allow socket reuse
        int opt = 1;
        if (setsockopt(server_fd, SOL_SOCKET, SO_REUSEADDR, &opt, sizeof(opt)) < 0) {
            std::cerr << "Failed to set socket options" << std::endl;
            close(server_fd);
            return false;
        }
        
        struct sockaddr_in address;
        address.sin_family = AF_INET;
        address.sin_addr.s_addr = INADDR_ANY;
        address.sin_port = htons(port);
        
        if (bind(server_fd, (struct sockaddr*)&address, sizeof(address)) < 0) {
            std::cerr << "Failed to bind socket to port " << port << std::endl;
            close(server_fd);
            return false;
        }
        
        if (listen(server_fd, 3) < 0) {
            std::cerr << "Failed to listen on socket" << std::endl;
            close(server_fd);
            return false;
        }
        
        running = true;
        std::cout << "CAN Message Server started on port " << port << std::endl;
        std::cout << "Waiting for GUI connections..." << std::endl;
        
        return true;
    }
    
    void run() {
        if (!running) return;
        
        while (running) {
            struct sockaddr_in client_addr;
            socklen_t client_len = sizeof(client_addr);
            
            int client_fd = accept(server_fd, (struct sockaddr*)&client_addr, &client_len);
            if (client_fd < 0) {
                if (running) {
                    std::cerr << "Failed to accept connection" << std::endl;
                }
                continue;
            }
            
            std::cout << "Client connected from " << inet_ntoa(client_addr.sin_addr) << std::endl;
            
            // Handle client in a separate thread
            std::thread client_thread(&SimpleCANServer::handleClient, this, client_fd);
            client_thread.detach();
        }
    }
    
    void handleClient(int client_fd) {
        char buffer[1024];
        
        while (running) {
            int bytes_read = recv(client_fd, buffer, sizeof(buffer) - 1, 0);
            if (bytes_read <= 0) {
                std::cout << "Client disconnected" << std::endl;
                break;
            }
            
            buffer[bytes_read] = '\0';
            std::string message(buffer);
            
            // Log the received CAN message
            std::cout << "Received CAN message: " << message << std::endl;
            
            // Parse and display the message format (expecting # as delimiter)
            size_t delimiter_pos = message.find('#');
            if (delimiter_pos != std::string::npos) {
                std::string can_id = message.substr(0, delimiter_pos);
                std::string data = message.substr(delimiter_pos + 1);
                
                std::cout << "  -> CAN ID: " << can_id << std::endl;
                std::cout << "  -> Data: " << data << std::endl;
            } else {
                std::cout << "  -> Invalid format (expected '#' delimiter)" << std::endl;
            }
            std::cout << "----------------------------------------" << std::endl;
        }
        
        close(client_fd);
    }
    
    void stop() {
        if (running) {
            running = false;
            if (server_fd != -1) {
                close(server_fd);
                server_fd = -1;
            }
        }
    }
};

int main(int argc, char* argv[]) {
    int port = 12345;
    
    if (argc > 1) {
        port = std::atoi(argv[1]);
    }
    
    std::cout << "=== CAN Message Test Server ===" << std::endl;
    std::cout << "This server will log all CAN messages received from the GUI" << std::endl;
    std::cout << "Expected message format: CAN_ID#DATA" << std::endl;
    std::cout << "Press Ctrl+C to stop the server" << std::endl;
    std::cout << "===============================" << std::endl;
    
    SimpleCANServer server(port);
    
    if (!server.start()) {
        std::cerr << "Failed to start server" << std::endl;
        return 1;
    }
    
    server.run();
    
    return 0;
}
