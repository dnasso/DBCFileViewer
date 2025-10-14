// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Joseph Ogle, Kunal Singh, and Deven Nasso

#include <iostream>
#include <string>
#include <vector>
#include <sstream>
#include <cassert>
#include <algorithm>

// Mock trim function (assuming it's defined elsewhere)
std::string trim(const std::string& str) {
    size_t first = str.find_first_not_of(' ');
    if (first == std::string::npos) return "";
    size_t last = str.find_last_not_of(' ');
    return str.substr(first, (last - first + 1));
}

// Mock isValidCanInterface (simplified for testing; in real code, check against discovered interfaces)
bool isValidCanInterface(const std::string& iface) {
    // For tests, assume vcan0, can0, vcan1 are valid
    return iface == "vcan0" || iface == "can0" || iface == "vcan1";
}

// Updated parsing function to match parseCansendPayload logic from server.cpp
bool parseCansendPayload(const std::string& payload, int defaultPriority, std::string& command, std::string& canIdData, std::string& canBus, int& intervalMs, int& priority, std::string& errorMsg) {
    std::vector<std::string> parts;
    std::stringstream ss(payload);
    std::string part;
    while (std::getline(ss, part, '#')) {
        parts.push_back(trim(part));
    }

    if (parts.size() < 4) {
        errorMsg = "ERROR: Invalid CANSEND syntax. Usage: CANSEND#<id>#<payload>#<time_ms>#<bus> [priority 0-9]\n";
        return false;
    }

    std::string canId = parts[0];
    std::string canPayload = parts[1];
    std::string timeStr = parts[2];
    canBus = parts[3];

    if (canId.starts_with("0x") || canId.starts_with("0X")) {
        canId = canId.substr(2);
    }

    if (timeStr.ends_with("ms")) {
        timeStr = timeStr.substr(0, timeStr.size() - 2);
    }

    priority = defaultPriority;
    if (parts.size() >= 5 && !parts[4].empty()) {
        std::string priorityStr = trim(parts[4]);
        if (priorityStr.size() == 1 && priorityStr[0] >= '0' && priorityStr[0] <= '9') {
            priority = priorityStr[0] - '0';
        }
    }

    if (!isValidCanInterface(canBus)) {
        errorMsg = "ERROR: CAN interface '" + canBus + "' is not available. Use LIST_CAN_INTERFACES to see available interfaces.\n";
        return false;
    }

    try {
        intervalMs = std::stoi(timeStr);
    } catch (...) {
        errorMsg = "ERROR: Invalid time value\n";
        return false;
    }

    if (intervalMs < 0) {
        errorMsg = "ERROR: Time value must be non-negative\n";
        return false;
    }

    canIdData = canId + "#" + canPayload;
    command = "cansend " + canBus + " " + canIdData;
    return true;
}

// Test functions
void testValidCansend() {
    std::string command, canIdData, canBus, errorMsg;
    int intervalMs, priority;

    // Test basic valid message
    assert(parseCansendPayload("123#deadbeef#1000#vcan0", 5, command, canIdData, canBus, intervalMs, priority, errorMsg));
    assert(command == "cansend vcan0 123#deadbeef");
    assert(canIdData == "123#deadbeef");
    assert(canBus == "vcan0");
    assert(intervalMs == 1000);
    assert(priority == 5);

    // Test with priority
    assert(parseCansendPayload("456#abcdef#500#can0#7", 5, command, canIdData, canBus, intervalMs, priority, errorMsg));
    assert(command == "cansend can0 456#abcdef");
    assert(canIdData == "456#abcdef");
    assert(canBus == "can0");
    assert(intervalMs == 500);
    assert(priority == 7);

    // Test with hex ID (0x stripped)
    assert(parseCansendPayload("0x123#beef#1000#vcan0", 5, command, canIdData, canBus, intervalMs, priority, errorMsg));
    assert(command == "cansend vcan0 123#beef");
    assert(canIdData == "123#beef");
    assert(canBus == "vcan0");
    assert(intervalMs == 1000);
    assert(priority == 5);

    // Test with ms suffix
    assert(parseCansendPayload("789#cafe#2000ms#vcan1", 5, command, canIdData, canBus, intervalMs, priority, errorMsg));
    assert(command == "cansend vcan1 789#cafe");
    assert(canIdData == "789#cafe");
    assert(canBus == "vcan1");
    assert(intervalMs == 2000);
    assert(priority == 5);

    // Test with extra spaces (trimmed)
    assert(parseCansendPayload(" 789 # beef # 2000 # vcan1 # 3 ", 5, command, canIdData, canBus, intervalMs, priority, errorMsg));
    assert(command == "cansend vcan1 789#beef");
    assert(canIdData == "789#beef");
    assert(canBus == "vcan1");
    assert(intervalMs == 2000);
    assert(priority == 3);

    std::cout << "testValidCansend passed\n";
}

void testInvalidCansend() {
    std::string command, canIdData, canBus, errorMsg;
    int intervalMs, priority;

    // Test too few parts
    assert(!parseCansendPayload("123#deadbeef#1000", 5, command, canIdData, canBus, intervalMs, priority, errorMsg));
    assert(errorMsg.find("Invalid CANSEND syntax") != std::string::npos);

    // Test invalid time
    assert(!parseCansendPayload("123#deadbeef#abc#vcan0", 5, command, canIdData, canBus, intervalMs, priority, errorMsg));
    assert(errorMsg.find("Invalid time value") != std::string::npos);

    // Test negative time
    assert(!parseCansendPayload("123#deadbeef#-1000#vcan0", 5, command, canIdData, canBus, intervalMs, priority, errorMsg));
    assert(errorMsg.find("Time value must be non-negative") != std::string::npos);

    // Test invalid CAN interface
    assert(!parseCansendPayload("123#deadbeef#1000#invalidbus", 5, command, canIdData, canBus, intervalMs, priority, errorMsg));
    assert(errorMsg.find("CAN interface 'invalidbus' is not available") != std::string::npos);

    // Test invalid priority (non-digit, defaults but still succeeds)
    assert(parseCansendPayload("123#deadbeef#1000#vcan0#a", 5, command, canIdData, canBus, intervalMs, priority, errorMsg));
    assert(priority == 5);  // Defaults to defaultPriority

    // Test priority out of range (multi-digit, defaults)
    assert(parseCansendPayload("123#deadbeef#1000#vcan0#10", 5, command, canIdData, canBus, intervalMs, priority, errorMsg));
    assert(priority == 5);  // Invalid, defaults

    std::cout << "testInvalidCansend passed\n";
}

// Additional test for edge cases
void testEdgeCases() {
    std::string command, canIdData, canBus, errorMsg;
    int intervalMs, priority;

    // Test empty payload
    assert(!parseCansendPayload("", 5, command, canIdData, canBus, intervalMs, priority, errorMsg));

    // Test only ID
    assert(!parseCansendPayload("123", 5, command, canIdData, canBus, intervalMs, priority, errorMsg));

    // Test zero time
    assert(parseCansendPayload("123#deadbeef#0#vcan0", 5, command, canIdData, canBus, intervalMs, priority, errorMsg));
    assert(intervalMs == 0);

    // Test uppercase 0X
    assert(parseCansendPayload("0X123#beef#1000#vcan0", 5, command, canIdData, canBus, intervalMs, priority, errorMsg));
    assert(canIdData == "123#beef");

    // Test priority 0
    assert(parseCansendPayload("123#deadbeef#1000#vcan0#0", 5, command, canIdData, canBus, intervalMs, priority, errorMsg));
    assert(priority == 0);

    // Test priority 9
    assert(parseCansendPayload("123#deadbeef#1000#vcan0#9", 5, command, canIdData, canBus, intervalMs, priority, errorMsg));
    assert(priority == 9);

    std::cout << "testEdgeCases passed\n";
}

int main() {
    testValidCansend();
    testInvalidCansend();
    testEdgeCases();
    std::cout << "All tests passed!\n";
    return 0;
}