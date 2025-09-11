/*
 * P1 SAMPLE CLIENT
 * ---------------
 * Author: Thoshitha Gamage
 * Date: 01/29/2025
 * License: MIT License
 * Description: This is a sample code for CS447 Spring 2025 P1 client code.
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
#include <optional>
#include <filesystem>
#include <format>
#include <array>

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

int main(int argc, char* argv[]) {
    if (argc!= 2) {
        std::cerr << "usage: client client.conf\n";
        return 1;
    }

    // Read configuration from file
    std::optional<std::string> serverIP, serverPort;
    std::filesystem::path configFilePath(argv[1]);

    if (!std::filesystem::is_regular_file(configFilePath)) {
        std::cerr << std::format("Error opening config file: {}\n", *argv);
        return 1;
    }

    std::ifstream configFile(argv[1]);
    std::string line;
    while (std::getline(configFile, line)) {
        if (line.find("SERVER_IP=") == 0) {
            serverIP = trim(line.substr(10));
        } else if (line.find("SERVER_PORT=") == 0) {
            serverPort = trim(line.substr(12));
        }
    }
    configFile.close();

    if (!serverIP.has_value() ||!serverPort.has_value()) {
        std::cerr << "Invalid config file format.\n";
        return 1;
    }

    // Set up connection hints
    addrinfo hints, *servinfo, *p;
    memset(&hints, 0, sizeof hints);
    hints.ai_family = AF_UNSPEC;
    hints.ai_socktype = SOCK_STREAM;

    // Get address information
    int rv = getaddrinfo(serverIP->c_str(), serverPort->c_str(), &hints, &servinfo);
    if (rv!= 0) {
        std::cerr << std::format("getaddrinfo: {}\n", gai_strerror(rv));
        return 1;
    }

    int sockfd;
    // Loop through results and try to connect
    for (p = servinfo; p!= nullptr; p = p->ai_next) {
        sockfd = socket(p->ai_family, p->ai_socktype, p->ai_protocol);
        if (sockfd == -1) {
            perror("client: socket");
            continue;
        }

        if (connect(sockfd, p->ai_addr, p->ai_addrlen) == -1) {
            perror("client: connect");
            close(sockfd);
            continue;
        }

        break;
    }

    if (p == nullptr) {
        std::cerr << "client: failed to connect\n";
        return 2;
    }

    // Display connection information
    char s[INET6_ADDRSTRLEN];
    inet_ntop(p->ai_family, get_in_addr((struct sockaddr*)p->ai_addr), s, sizeof s);
    std::cout << std::format("client: connecting to {}\n", s);

    freeaddrinfo(servinfo);

    std::array<char, MAXDATASIZE> buf;
    std::string userInput;
    bool niceExit = false;

    // Interactive loop for sending and receiving messages
    while (niceExit == false) {
        std::cout << "> ";
        std::getline(std::cin, userInput);

        if (userInput.empty()) {
            continue;
        }

        if (userInput == "exit") {
            break; // Exit the loop if the user types "exit"
        }/* else if (userInput == "BYE"){
            niceExit = true;
            break;
        }*/

        if (send(sockfd, userInput.c_str(), userInput.size(), 0) == -1) {
            perror("send");
            break;
        }

        int numbytes = recv(sockfd, buf.data(), MAXDATASIZE - 1, 0);
        if (numbytes == -1) {
            perror("recv");
            break;
        } else if (numbytes == 0) {
            std::cout << "Server closed the connection.\n";
            break;
        }

        buf[numbytes] = '\0';
        std::cout << std::format("Server: {}\n", buf.data());
    }

    close(sockfd);
    return 0;
}
