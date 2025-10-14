// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Joseph Ogle, Kunal Singh, and Deven Nasso

#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <unistd.h>
#include <cstring>
#include <iostream>
#include <cassert>
#include <string>
#include <thread>
#include <chrono>

// Connect to running server and send command
class TcpSession {
public:
    TcpSession(const std::string& host = "127.0.0.1", uint16_t port = 50123) {
        sockfd = socket(AF_INET, SOCK_STREAM, 0);
        if (sockfd < 0) {
            return;
        }

        std::memset(&serv_addr, 0, sizeof(serv_addr));
        serv_addr.sin_family = AF_INET;
        serv_addr.sin_port = htons(port);

        if (inet_pton(AF_INET, host.c_str(), &serv_addr.sin_addr) <= 0) {
            close(sockfd);
            sockfd = -1;
            return;
        }

        if (connect(sockfd, reinterpret_cast<struct sockaddr*>(&serv_addr), sizeof(serv_addr)) < 0) {
            close(sockfd);
            sockfd = -1;
        }
    }

    ~TcpSession() {
        if (sockfd >= 0) {
            close(sockfd);
        }
    }

    bool valid() const { return sockfd >= 0; }

    bool sendAndReceive(const std::string& cmd, std::string& response) {
        if (!valid()) return false;
        if (::send(sockfd, cmd.c_str(), cmd.size(), 0) < 0) {
            return false;
        }

        char buffer[2048] = {0};
        int n = recv(sockfd, buffer, sizeof(buffer) - 1, 0);
        if (n <= 0) {
            return false;
        }

        response.assign(buffer, n);
        return true;
    }

private:
    int sockfd = -1;
    struct sockaddr_in serv_addr {};
};

bool sendCommand(const std::string& cmd, std::string& response) {
    TcpSession session;
    if (!session.valid()) return false;
    return session.sendAndReceive(cmd, response);
}

std::string extractTaskId(const std::string& text) {
    const std::string key = "task ID: ";
    auto pos = text.find(key);
    if (pos == std::string::npos) return {};
    pos += key.size();
    auto end = text.find_first_of("\r\n", pos);
    if (end == std::string::npos) {
        end = text.size();
    }
    return text.substr(pos, end - pos);
}

int main() {
    std::string response;

    // Test basic CANSEND
    assert(sendCommand("CANSEND#123#DEADBEEF#1000#vcan0\n", response));
    assert(response.find("OK: CANSEND scheduled") != std::string::npos);
    std::cout << "Integration test: basic CANSEND passed\n";

    // Test CANSEND with hex ID, ms suffix, and priority
    assert(sendCommand("CANSEND#0x321#ABCDEF00#250ms#vcan0#9\n", response));
    assert(response.find("OK: CANSEND scheduled") != std::string::npos);
    std::cout << "Integration test: CANSEND hex/prio passed\n";

    // Validate interface guard rails
    assert(sendCommand("CANSEND#111#ABCD#100#notreal\n", response));
    assert(response.find("ERROR: CAN interface") != std::string::npos);
    std::cout << "Integration test: invalid CAN interface guard passed\n";

    // Adjust log level
    assert(sendCommand("SET_LOG_LEVEL INFO\n", response));
    assert(response.find("Log level set to INFO") != std::string::npos);
    std::cout << "Integration test: SET_LOG_LEVEL passed\n";

    // Inspect server thread registry
    assert(sendCommand("LIST_THREADS\n", response));
    assert(response.find("Active threads") != std::string::npos);
    std::cout << "Integration test: LIST_THREADS passed\n";

    // Ensure LIST_TASKS responds even with no client state
    assert(sendCommand("LIST_TASKS\n", response));
    assert(response.find("Active tasks:") != std::string::npos);
    std::cout << "Integration test: LIST_TASKS (stateless) passed\n";

    // Exercise single-shot lifecycle within one session
    {
        TcpSession session;
        assert(session.valid());
        std::cout << "Integration test: persistent session established\n";

        std::string sendResp;
        assert(session.sendAndReceive("SEND_TASK#124#CAFEBABE#500#vcan0\n", sendResp));
        assert(sendResp.find("OK: SEND_TASK scheduled") != std::string::npos);
        std::string taskId = extractTaskId(sendResp);
        assert(!taskId.empty());

        std::string pauseResp;
        assert(session.sendAndReceive("PAUSE " + taskId + "\n", pauseResp));
        assert(pauseResp.find("Paused " + taskId) != std::string::npos);

        std::string listPaused;
        assert(session.sendAndReceive("LIST_TASKS\n", listPaused));
        assert(listPaused.find("paused") != std::string::npos);

        std::string resumeResp;
        assert(session.sendAndReceive("RESUME " + taskId + "\n", resumeResp));
        assert(resumeResp.find("Resumed " + taskId) != std::string::npos);

        std::this_thread::sleep_for(std::chrono::milliseconds(600));

        std::string listAfterRun;
        assert(session.sendAndReceive("LIST_TASKS\n", listAfterRun));
        assert(listAfterRun.find("once (completed)") != std::string::npos ||
               listAfterRun.find("once (error)") != std::string::npos);

        std::string killResp;
        assert(session.sendAndReceive("KILL_TASK " + taskId + "\n", killResp));
        assert(killResp.find("Task " + taskId + " killed") != std::string::npos);

        std::string killAllResp;
        assert(session.sendAndReceive("KILL_ALL_TASKS\n", killAllResp));
        assert(killAllResp.find("All tasks killed") != std::string::npos);
    }
    std::cout << "Integration test: single-shot task lifecycle passed\n";

    // Exercise recurring task lifecycle within one session
    {
        TcpSession session;
        assert(session.valid());
        std::string resp;
        assert(session.sendAndReceive("CANSEND#200#01020304#150#vcan0#8\n", resp));
        assert(resp.find("OK: CANSEND scheduled") != std::string::npos);
        std::string taskId = extractTaskId(resp);
        assert(!taskId.empty());

        std::string listResp;
        assert(session.sendAndReceive("LIST_TASKS\n", listResp));
        assert(listResp.find("every 150ms priority 8") != std::string::npos);

        std::string killResp;
        assert(session.sendAndReceive("KILL_TASK " + taskId + "\n", killResp));
        assert(killResp.find("Task " + taskId + " killed") != std::string::npos);

        std::string killAllResp;
        assert(session.sendAndReceive("KILL_ALL_TASKS\n", killAllResp));
        assert(killAllResp.find("All tasks killed") != std::string::npos);
    }
    std::cout << "Integration test: recurring task lifecycle passed\n";

    // CAN interface listing
    assert(sendCommand("LIST_CAN_INTERFACES\n", response));
    assert(response.find("Available CAN interfaces") != std::string::npos ||
           response.find("No CAN interfaces available") != std::string::npos);
    std::cout << "Integration test: LIST_CAN_INTERFACES passed\n";

    // Unknown command handling
    assert(sendCommand("UNKNOWN_COMMAND\n", response));
    assert(response.find("Unknown command") != std::string::npos);
    std::cout << "Integration test: unknown command passed\n";

    // Cleanup commands
    assert(sendCommand("KILL_ALL_TASKS\n", response));
    assert(response.find("All tasks killed") != std::string::npos);
    std::cout << "Integration test: KILL_ALL_TASKS standalone passed\n";

    assert(sendCommand("KILL_ALL\n", response));
    assert(response.find("All processes killed") != std::string::npos);
    std::cout << "Integration test: KILL_ALL passed\n";

    std::cout << "All integration tests passed!\n";
}