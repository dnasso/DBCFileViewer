/*
DBCFileViewer_Client - Team QT (cute) Devs
arm_client.cpp
Todo: add license stuff, maybe add candump-like features to report to frontend
check if threads are registering 
//add toggle for message. pauses sending but keeps the thread alive
//update frontend info "message"
//add error message for config file handling
//todo client can change port used by server
//think about removing the wait for messages in the client, so the client can send very quickly. (maybe not)
//compare to p3, add command map and check other features
//add feature to restart server from client
*/

/*
enqueue without deadline (existing behavior): pool.enqueue(0, []{ work });
                //enqueue with a deadline 200ms from now and drop if missed: pool.enqueue_deadline(std::chrono::steady_clock::now() + std::chrono::milliseconds(200), 5, true, []{ work });
                // pool.enqueue_deadline(deadline, prio, drop, [receivedMsg]{ work });

                // Submit to thread pool
                // todo: change this so it runs every canTime ms instead of only deadline. it maybe needs to reschdule itself or run on a timer
*/

#include <stdio.h>
#include <stdlib.h>
#include <iostream>
#include <string>
#include <cstring>
#include <unistd.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <netdb.h>
#include <arpa/inet.h>
#include <sys/wait.h>
#include <signal.h>
#include <cerrno>
#include <system_error>
#include <fstream>
#include <algorithm>
#include <array>
#include <optional>
#include <filesystem>
#include <format>
#include <thread>
#include <chrono>
#include <mutex>
#include <vector>
#include <queue>
#include <functional>
#include <condition_variable>
#include <atomic>
#include <sstream>

#define BACKLOG 10
#define MAXDATASIZE 10000

// config file variables. parsed in main
int port = 0;
std::string log_level_str = "ERROR"; // ERROR by default but overwritten by config file
int log_level = 30; //INFO == 10, WARNING == 20, ERROR == 30, DEBUG == 5
const int INFO = 10;
const int WARNING = 20;
const int ERROR = 30;
const int DEBUG = 5;

// Helper function to trim whitespace and invisible characters from string
std::string trim(const std::string& str) {
    size_t first = str.find_first_not_of(" \t\r\n\f\v");
    if (first == std::string::npos) return "";
    size_t last = str.find_last_not_of(" \t\r\n\f\v");
    return str.substr(first, last - first + 1);
}

struct ThreadInfo {
    std::thread::id id;
    std::string name;
    std::string status;
    std::chrono::steady_clock::time_point start_time;
};

class ThreadRegistry {
private:
    std::vector<ThreadInfo> threads;
    std::mutex mtx;

public:
    void add(const std::thread::id& id, const std::string& name) {
        std::lock_guard<std::mutex> lock(mtx);
        ThreadInfo info;
        info.id = id;
        info.name = name;
        info.status = "running";
        info.start_time = std::chrono::steady_clock::now();
        threads.push_back(info);
    }

    void remove(const std::thread::id& id) {
        std::lock_guard<std::mutex> lock(mtx);
        threads.erase(
            std::remove_if(threads.begin(), threads.end(),
                           [&id](const ThreadInfo& t) { return t.id == id; }),
            threads.end()
        );
    }

    void print() {
        std::lock_guard<std::mutex> lock(mtx);
        std::cout << "Active threads:\n";
        for (const auto& t : threads)
            std::cout << "  " << t.id << " (" << t.name << ")\n";
    }

    std::string toString() {
        std::lock_guard<std::mutex> lock(mtx);
        std::ostringstream oss;
        oss << "Active threads:\n";
        for (const auto& t : threads)
            oss << "  " << t.id << " (" << t.name << ")\n";
        return oss.str();
    }
};

// Global registry
ThreadRegistry registry;

// Signal handler for SIGCHLD
void sigchld_handler(int s) {
    (void)s;
    int saved_errno = errno;
    while (waitpid(-1, NULL, WNOHANG) > 0);
    errno = saved_errno;
}

// Get sockaddr, IPv4 or IPv6
void* get_in_addr(struct sockaddr* sa) {
    if (sa->sa_family == AF_INET) {
        return &(((struct sockaddr_in*)sa)->sin_addr);
    }
    return &(((struct sockaddr_in6*)sa)->sin6_addr);
}

//maybe add command map

// Log events with timestamp
void logEvent(int level, const std::string& message) { //logging with hierarchy
    if (level < log_level) {
        return; // Skip logging if message severity is below configured log_level
    }
    std::ofstream log("server.log", std::ios::app);
    auto now = std::chrono::system_clock::now();
    auto in_time_t = std::chrono::system_clock::to_time_t(now);
    log << "[" << std::put_time(std::localtime(&in_time_t), "%Y-%m-%d %H:%M:%S") << "] [" << level << "] " << message << std::endl;
}

class ThreadPool {
public:
    explicit ThreadPool(size_t n = std::thread::hardware_concurrency()) : stop(false), seq(0) {
        if (n == 0) n = 1;
        for (size_t i = 0; i < n; ++i) {
            threads.emplace_back([this] {
                registry.add(std::this_thread::get_id(), "thread pool worker");  // Add to registry
                for (;;) {
                    Task task;
                    {
                        std::unique_lock<std::mutex> lock(this->mtx);
                        this->cv.wait(lock, [this] { return this->stop || !this->pq.empty(); });
                        if (this->stop && this->pq.empty()) {
                            registry.remove(std::this_thread::get_id());  // Remove from registry
                            return;
                        }
                        task = std::move(this->pq.top());
                        this->pq.pop();
                    }

                    auto now = std::chrono::steady_clock::now();
                    // If task had a deadline and was marked to be dropped when missed, skip it
                    if (task.drop_if_missed && now > task.deadline) {
                        logEvent(WARNING, "Dropped task that missed its deadline");
                        continue;
                    }

                    try {
                        task.func();
                    } catch (...) {
                        logEvent(ERROR, "Unhandled exception in threadpool task");
                    }
                }
            });
        }
    }

    // Enqueue a normal (no-deadline) task with optional priority (higher = run earlier when deadlines tie)
    template <class F>
    void enqueue(int priority, F&& f) {
        enqueue_impl(std::chrono::steady_clock::time_point::max(), priority, false, std::forward<F>(f));
    }

    // Enqueue with an absolute deadline (steady_clock::time_point). If drop_if_missed==true the task
    // will be discarded if the worker picks it up after the deadline has passed.
    template <class F>
    void enqueue_deadline(std::chrono::steady_clock::time_point deadline,
                          int priority,
                          bool drop_if_missed,
                          F&& f) {
        enqueue_impl(deadline, priority, drop_if_missed, std::forward<F>(f));
    }

    ~ThreadPool() {
        {
            std::lock_guard<std::mutex> lock(mtx);
            stop = true;
        }
        cv.notify_all();
        for (auto &t : threads) if (t.joinable()) t.join();
    }

private:
    struct Task {
        std::chrono::steady_clock::time_point deadline;
        int priority;
        std::size_t seq;
        std::function<void()> func;
        bool drop_if_missed;
    };

    struct Cmp {
        bool operator()(Task const& a, Task const& b) const {
            // earlier deadline should come first
            if (a.deadline != b.deadline) return a.deadline > b.deadline;
            // higher priority should come first
            if (a.priority != b.priority) return a.priority < b.priority;
            // preserve FIFO for equal deadline+priority
            return a.seq > b.seq;
        }
    };

    template <class F>
    void enqueue_impl(std::chrono::steady_clock::time_point deadline,
                      int priority,
                      bool drop_if_missed,
                      F&& f) {
        std::function<void()> fn(std::forward<F>(f));
        {
            std::lock_guard<std::mutex> lock(mtx);
            pq.push(Task{deadline, priority, seq++, std::move(fn), drop_if_missed});
        }
        cv.notify_one();
    }

    std::vector<std::thread> threads;
    std::priority_queue<Task, std::vector<Task>, Cmp> pq;
    std::mutex mtx;
    std::condition_variable cv;
    bool stop;
    std::atomic<std::size_t> seq;
};

int main(int argc, char* argv[]) {
    int sockfd, new_fd;
    struct addrinfo hints, *servinfo, *p;
    struct sockaddr_storage their_addr;
    socklen_t sin_size;
    struct sigaction sa;
    int yes = 1;
    char s[INET6_ADDRSTRLEN];
    int rv;

    
    

    std::memset(&hints, 0, sizeof hints);
    hints.ai_family = AF_UNSPEC;
    hints.ai_socktype = SOCK_STREAM;
    hints.ai_flags = AI_PASSIVE;

    if (argc != 2) {
        std::cerr << std::format("Usage: {} <config_file>\n", *argv);
        logEvent(DEBUG, "server <config_file> has incorrect number of arguments");
        return 1;
    }

    std::string configFileName = argv[1];
    std::optional<std::string> port;

    std::filesystem::path configFilePath(configFileName);
    if (!std::filesystem::is_regular_file(configFilePath)) {
        std::cerr << std::format("Error opening configuration file: {}\n", configFileName);
        logEvent(ERROR, "Error opening configuration file: " + configFileName);
        return 1;
    }

    std::ifstream configFile(configFileName);
    std::string line;
    while (std::getline(configFile, line)) {
        std::string_view lineView(line);
        if (lineView.substr(0, 5) == "PORT=") {
            std::string portStr = trim(std::string(lineView.substr(5)));
            port = portStr;
            logEvent(DEBUG, "Port set to " + *port);
        } else if (lineView.substr(0, 10) == "LOG_LEVEL=") {
            std::string logLevelStr = trim(std::string(lineView.substr(10)));
            log_level_str = logLevelStr;
            if (logLevelStr == "DEBUG") {
                log_level = DEBUG;
            } else if (logLevelStr == "INFO") {
                log_level = INFO;
            } else if (logLevelStr == "WARNING") {
                log_level = WARNING;
            } else if (logLevelStr == "ERROR") {
                log_level = ERROR;
            } else {
                logEvent(WARNING, "Unknown log level '" + logLevelStr + "', using ERROR");
                log_level = ERROR;
                log_level_str = "ERROR";
            }
            logEvent(DEBUG, "Log level set to " + log_level_str);
        }
    }
    configFile.close();

    if (!port.has_value()) {
        std::cerr << "Port number not found in configuration file!\n";
        logEvent(ERROR, "Port number not found in configuration file!");
        return 1;
    }

    // Convert port string to int
    try {
        ::port = std::stoi(*port);
    } catch (const std::exception& e) {
        std::cerr << "Invalid port number in configuration file!\n";
        logEvent(ERROR, "Invalid port number in configuration file!");
        return 1;
    }

    if ((rv = getaddrinfo(nullptr, std::to_string(::port).c_str(), &hints, &servinfo))!= 0) {
        std::cerr << std::format("getaddrinfo: {}\n", gai_strerror(rv));
        logEvent(ERROR, std::string("getaddrinfo: ") + gai_strerror(rv));
        return 1;
    }

    // Loop through all the results and bind to the first we can
    for (p = servinfo; p!= NULL; p = p->ai_next) {
        if ((sockfd = socket(p->ai_family, p->ai_socktype, p->ai_protocol)) == -1) {
            std::perror("server: socket");
            logEvent(ERROR, "server: socket");
            continue;
        }

        if (setsockopt(sockfd, SOL_SOCKET, SO_REUSEADDR, &yes, sizeof(int)) == -1) {
            logEvent(ERROR, "setsockopt");
            throw std::system_error(errno, std::generic_category(), "setsockopt");
        }

        if (bind(sockfd, p->ai_addr, p->ai_addrlen) == -1) {
            close(sockfd);
            std::perror("server: bind");
            logEvent(ERROR, "server: bind");
            continue;
        }

        break;
    }

    freeaddrinfo(servinfo);

    if (p == NULL) {
        std::cerr << "server: failed to bind\n";
        logEvent(ERROR, "server: failed to bind");
        return 2;
    }

    if (listen(sockfd, BACKLOG) == -1) {
        logEvent(ERROR, "server: listen");
        throw std::system_error(errno, std::generic_category(), "listen");
    }

    sa.sa_handler = sigchld_handler; // Reap all dead processes
    sigemptyset(&sa.sa_mask);
    sa.sa_flags = SA_RESTART;
    if (sigaction(SIGCHLD, &sa, NULL) == -1) {
        logEvent(ERROR, "server: sigaction");
        throw std::system_error(errno, std::generic_category(), "sigaction");
    }

    logEvent(INFO, "server: waiting for connections...");
    std::cout << "server: waiting for connections...\n";

    ThreadPool pool(std::max<size_t>(1, std::min<size_t>(2, std::thread::hardware_concurrency()))); // prefer 2 threads, but at least 1

    while (true) {
        sin_size = sizeof their_addr;
        new_fd = accept(sockfd, (struct sockaddr*)&their_addr, &sin_size);
        if (new_fd == -1) {
            logEvent(ERROR, "server: accept");
            std::perror("accept");
            continue;
        }

        inet_ntop(their_addr.ss_family, get_in_addr((struct sockaddr*)&their_addr), s, sizeof s);
        std::cout << "Connection from: " << s << std::endl;
        /*
        if (send (new_fd, "Hello, you are connected to the server!\n", 39, 0) == -1) {
            logEvent(ERROR, "send");
            std::perror("send");
        }
            */
        logEvent(INFO, "Connection from: " + std::string(s));

        // Create a new thread to handle the client communication
        std::thread clientThread([new_fd, s, &pool]() {
            registry.add(std::this_thread::get_id(), "client handler for " + std::string(s));  // Add to registry
            std::array<char, MAXDATASIZE> buf;
            int numbytes;
            bool niceShutdown = false;
            int priority = 5; //needs to be implemented in the ui
            int canTime; //time in ms between CAN messages sending
            std::string canInterface; //can0, vcan1, etc.
            std::string canIdStr; //CAN ID and data in hex
            std::vector<pid_t> clientPids;  // Track PIDs of spawned processes

            auto setupRecurringCansend = [&](const std::string& cmd, int ct, int priority, ThreadPool& pool, std::vector<pid_t>& clientPids) {
                // create a self-rescheduling task that repeatedly runs the same command every canTime ms
                auto recurring = std::make_shared<std::function<void()>>();
                std::string m = cmd; // snapshot the command
                int interval = ct; // snapshot the interval

                *recurring = [recurring, m, interval, &pool, priority, &clientPids]() mutable {
                    // Replace system() with fork()/execl() to track PID
                    pid_t pid = fork();
                    if (pid == 0) {
                        // Child process
                        execl("/bin/sh", "sh", "-c", m.c_str(), NULL);
                        _exit(1);  // Exit if exec fails
                    } else if (pid > 0) {
                        // Parent process: store PID
                        clientPids.push_back(pid);
                    } else {
                        logEvent(ERROR, "fork() failed: " + std::string(strerror(errno)));
                    }
                    // schedule next run interval ms from now
                    pool.enqueue_deadline(std::chrono::steady_clock::now() + std::chrono::milliseconds(interval),
                                          priority,
                                          false,
                                          [recurring]() { // capture recurring to continue the chain
                                              try {
                                                  (*recurring)();
                                              } catch (...) {
                                                  logEvent(ERROR, "Unhandled exception in recurring cansend task");
                                              }
                                          });
                };

                // schedule the first run
                pool.enqueue_deadline(std::chrono::steady_clock::now() + std::chrono::milliseconds(interval),
                                      priority,
                                      false,
                                      [recurring]() {
                                          try {
                                              (*recurring)();
                                          } catch (...) {
                                              logEvent(ERROR, "Unhandled exception in recurring cansend task");
                                          }
                                      });
            };

            while (!niceShutdown) {
                if ((numbytes = recv(new_fd, buf.data(), MAXDATASIZE - 1, 0)) == -1) {
                    logEvent(ERROR, "recv");
                    perror("recv");
                    exit(1);
                } else if (numbytes == 0) {
                    logEvent(INFO, "Client disconnected: " + std::string(s));
                    break;
                }

                buf[numbytes] = '\0';
                std::string receivedMsg(buf.data(), static_cast<size_t>(numbytes));
                logEvent(DEBUG, "Received from " + std::string(s) + ": " + receivedMsg);

                //make command parsing function here for separating values in receivedMsg, shutdown, polling thread list, killing threads, etc.
                if (receivedMsg == "SHUTDOWN") {
                    logEvent(INFO, "Received SHUTDOWN command from " + std::string(s));
                    niceShutdown = true;
                    continue;
                } 
                else if (receivedMsg == "KILL_ALL") {
                    logEvent(INFO, "Received KILL_ALL command from " + std::string(s));
                    for (auto pid : clientPids) {
                        if (kill(pid, SIGTERM) == -1) {  // Send SIGTERM to each process
                            logEvent(WARNING, "Failed to kill PID " + std::to_string(pid) + ": " + std::string(strerror(errno)));
                        }
                    }
                    clientPids.clear();  // Clear the list
                    send(new_fd, "All processes killed.\n", 48, 0);
                    continue;
                }
                else if (receivedMsg.rfind("cansend ", 0) == 0) { // parse "cansend <if> <id#data> <time>". priority and drop_if_missed are not implemented yet
                    std::string payload = receivedMsg.substr(8);
                    // trim leading whitespace. might need to trim more (or more types) if errors occur
                    while (!payload.empty() && (payload.front() == ' ' || payload.front() == '\t')) payload.erase(payload.begin());

                    auto p1 = payload.find(' ');
                    if (p1 == std::string::npos) {
                        logEvent(ERROR, "Invalid cansend syntax from " + std::string(s));
                        send(new_fd, "ERROR: Invalid cansend syntax. Usage: cansend <interface> <id#data> <time>\n", 80, 0);
                    } 
                    else {
                        canInterface = payload.substr(0, p1);
                        auto p2 = payload.find(' ', p1 + 1);
                        if (p2 == std::string::npos) {
                            logEvent(ERROR, "Invalid cansend syntax from " + std::string(s));
                            send(new_fd, "ERROR: Invalid cansend syntax. Usage: cansend <interface> <id#data> <time>\n", 80, 0);
                        } 
                        else {
                            canIdStr = payload.substr(p1 + 1, p2 - (p1 + 1));
                            std::string timeStr = payload.substr(p2 + 1);
                            // trim timeStr
                            while (!timeStr.empty() && (timeStr.back() == '\r' || timeStr.back() == '\n' || timeStr.back() == ' ' || timeStr.back() == '\t')) timeStr.pop_back();
                            while (!timeStr.empty() && (timeStr.front() == ' ' || timeStr.front() == '\t')) timeStr.erase(timeStr.begin());

                            try {
                                canTime = std::stoi(timeStr);
                                logEvent(INFO, "Parsed cansend: " + canInterface + " " + canIdStr + " every " + std::to_string(canTime) + "ms from " + std::string(s));
                                // Submit to thread pool
                                std::string cmd = ("cansend " + canInterface + " " + canIdStr); // + " > /dev/null 2>&1" temp remove for debugging
                                setupRecurringCansend(cmd, canTime, priority, pool, clientPids);  // Pass clientPids
                                send(new_fd, "OK: Cansend scheduled\n", 23, 0);
                            }
                            catch (...) {
                                logEvent(ERROR, "Invalid cansend time from " + std::string(s));
                                send(new_fd, "ERROR: Invalid time value\n", 26, 0);
                            }
                        }
                    }

                } else if (receivedMsg == "LIST_THREADS") { // for sending to the ui for info. probably will send every few seconds or on demand
                    logEvent(INFO, "Received LIST_THREADS command from " + std::string(s));
                    send(new_fd, registry.toString().c_str(), registry.toString().size(), 0);
                    continue;

                } else if (receivedMsg.rfind("KILL_THREAD ", 0) == 0) { //client needs to get thread id from LIST_THREADS data
                    std::string threadIdStr = receivedMsg.substr(12);
                    try {
                        std::thread::id threadId = std::thread::id(std::stoull(threadIdStr));
                        registry.remove(threadId);
                        logEvent(INFO, "Removed thread " + threadIdStr + " as per request from " + std::string(s));
                        send(new_fd, "Thread removed\n", 16, 0);
                    } catch (const std::exception& e) {
                        logEvent(ERROR, "Invalid thread ID in KILL_THREAD command from " + std::string(s));
                        send(new_fd, "Invalid thread ID\n", 18, 0);
                    }
                    continue;

                } else if (receivedMsg.rfind("SET_LOG_LEVEL ", 0) == 0) { // add an interface in the UI to show the log file to make this useful
                    std::string levelStr = receivedMsg.substr(14);
                    if (levelStr == "DEBUG") {
                        log_level = DEBUG;
                        log_level_str = "DEBUG";
                    } else if (levelStr == "INFO") {
                        log_level = INFO;
                        log_level_str = "INFO";
                    } else if (levelStr == "WARNING") {
                        log_level = WARNING;
                        log_level_str = "WARNING";
                    } else if (levelStr == "ERROR") {
                        log_level = ERROR;
                        log_level_str = "ERROR";
                    } else {
                        logEvent(ERROR, "Invalid log level in SET_LOG_LEVEL command from " + std::string(s));
                        send(new_fd, "Invalid log level\n", 18, 0);
                        continue;
                    }
                    logEvent(INFO, "Log level set to " + log_level_str + " as per request from " + std::string(s));
                    send(new_fd, ("Log level set to " + log_level_str + "\n").c_str(), log_level_str.size() + 16, 0);
                    continue;
                }
                else if (receivedMsg == "RESTART") { //restart the server. not implemented yet
                    logEvent(INFO, "Received RESTART command from " + std::string(s));
                    // Implement restart logic here
                    send(new_fd, "Server restart not implemented yet.\n", 36, 0);
                }
                else {
                    logEvent(WARNING, "Unknown command from " + std::string(s) + ": " + receivedMsg);
                    std::string response = "Unknown command: " + receivedMsg;
                    send(new_fd, response.c_str(), response.size(), 0);
                }
            }

            // Clean up any remaining PIDs on disconnect
            for (auto pid : clientPids) {
                kill(pid, SIGTERM);
            }
            clientPids.clear();

            close(new_fd);
            registry.remove(std::this_thread::get_id());  // Remove from registry
        });

        clientThread.detach();
    }

    return 0;
}
