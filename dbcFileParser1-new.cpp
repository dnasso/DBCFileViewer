#include <iostream>
#include <fstream>
#include <sstream>
#include <vector>
#include <string>
#include <cstdlib>
#include <regex>

// Data structures for CAN messages and signals
struct canSignal {
    std::string name;
    int startBit;
    int length;
    bool littleEndian;
    double factor;
    double offset;
    double min;
    double max;
    std::string unit;
};

struct canMessage {
    unsigned long id;
    std::string name;
    int length;
    std::vector<canSignal> signals;
};

std::vector<canMessage> messages;

// Helper function to trim spaces from beginning and end of a string.
std::string trim(const std::string& s) {
    size_t start = s.find_first_not_of(" \t");
    size_t end = s.find_last_not_of(" \t");
    if (start == std::string::npos) return "";
    return s.substr(start, end - start + 1);
}

// Display the raw contents of the DBC file for debugging
void displayDBCFileContents(const std::string& filename) {
    std::ifstream infile(filename.c_str());
    if (!infile) {
        std::cerr << "Error opening file " << filename << std::endl;
        return;
    }
    
    std::cout << "\n=== DBC File Contents ===\n";
    std::string line;
    int lineNum = 1;
    while (getline(infile, line)) {
        // Only display signal and message lines to keep output manageable
        if (line.find("BO_") != std::string::npos || line.find(" SG_") != std::string::npos) {
            std::cout << lineNum << ": " << line << std::endl;
        }
        lineNum++;
    }
    std::cout << "=== End of File ===\n\n";
    infile.close();
}

// Parse the DBC file.
void parseDBC(const std::string& filename) {
    std::ifstream infile(filename.c_str());
    if (!infile) {
        std::cerr << "Error opening file " << filename << std::endl;
        std::exit(EXIT_FAILURE);
    }
    
    std::string line;
    while (getline(infile, line)) {
        // Check if this line starts a new CAN message.
        if (line.compare(0, 3, "BO_") == 0) {
            canMessage msg;
            std::istringstream iss(line);
            std::string token;
            
            // Skip "BO_"
            iss >> token;
            
            // Next token is the message ID.
            iss >> msg.id;
            
            // Next token is the message name
            iss >> msg.name;
            
            // Skip the colon
            std::string colon;
            iss >> colon;
            
            // Read the message length
            iss >> msg.length;
            
            msg.signals.clear();
            messages.push_back(msg);
        }
        // Look for signal definitions
        else if (line.find(" SG_") != std::string::npos) {
            canSignal sig;
            
            // Using regex to parse the signal line
            std::regex signal_regex(" SG_ ([^ ]+) : (\\d+)\\|(\\d+)@(\\d)([\\+\\-]) \\(([^,]+),([^\\)]+)\\) \\[([^\\|]+)\\|([^\\]]+)\\] \"([^\"]*)\" (.*)");
            std::smatch matches;
            
            if (std::regex_search(line, matches, signal_regex)) {
                // Extract captured groups
                sig.name = matches[1];
                sig.startBit = std::stoi(matches[2]);
                sig.length = std::stoi(matches[3]);
                sig.littleEndian = (matches[4] == "1");
                // matches[5] contains the sign indicator (+/-)
                
                try {
                    sig.factor = std::stod(matches[6]);
                    sig.offset = std::stod(matches[7]);
                    sig.min = std::stod(matches[8]);
                    sig.max = std::stod(matches[9]);
                } catch (const std::exception& e) {
                    std::cerr << "Error parsing numeric values in signal " << sig.name << ": " << e.what() << std::endl;
                    sig.factor = 1.0;
                    sig.offset = 0.0;
                    sig.min = 0.0;
                    sig.max = 0.0;
                }
                
                sig.unit = matches[10];
                
                // Attach signal to the last message parsed
                if (!messages.empty()) {
                    messages.back().signals.push_back(sig);
                } else {
                    std::cerr << "Warning: Signal found but no message to attach to: " << sig.name << std::endl;
                }
            } else {
                // If regex doesn't match, try a fallback parsing method
                std::istringstream iss(line);
                std::string dummy, signalName, colonDummy;
                
                // Skip whitespace and "SG_"
                iss >> dummy;  // Should be "SG_"
                
                // Extract Signal Name
                iss >> signalName;
                sig.name = signalName;
                
                // Skip colon if present
                iss >> colonDummy;  // Should be ":"
                
                // Extract bit position info
                std::string bitInfo;
                iss >> bitInfo;
                
                size_t pipePos = bitInfo.find("|");
                size_t atPos = bitInfo.find("@");
                
                if (pipePos != std::string::npos && atPos != std::string::npos) {
                    try {
                        sig.startBit = std::stoi(bitInfo.substr(0, pipePos));
                        sig.length = std::stoi(bitInfo.substr(pipePos + 1, atPos - pipePos - 1));
                        // Little endian if 1, Big endian if 0
                        sig.littleEndian = (bitInfo[atPos + 1] == '1');
                    } catch (const std::exception& e) {
                        std::cerr << "Error parsing bit field: " << bitInfo << " - " << e.what() << std::endl;
                        // Set defaults
                        sig.startBit = 0;
                        sig.length = 0;
                        sig.littleEndian = false;
                    }
                }
                
                // Extract scaling info (factor,offset)
                std::string scaleInfo;
                iss >> scaleInfo;
                
                if (scaleInfo.size() > 2 && scaleInfo.front() == '(' && scaleInfo.back() == ')') {
                    std::string factorOffset = scaleInfo.substr(1, scaleInfo.size() - 2);
                    size_t commaPos = factorOffset.find(",");
                    if (commaPos != std::string::npos) {
                        try {
                            sig.factor = std::stod(factorOffset.substr(0, commaPos));
                            sig.offset = std::stod(factorOffset.substr(commaPos + 1));
                        } catch (const std::exception& e) {
                            std::cerr << "Error parsing factor/offset: " << factorOffset << " - " << e.what() << std::endl;
                            sig.factor = 1.0;
                            sig.offset = 0.0;
                        }
                    }
                }
                
                // Extract range info [min|max]
                std::string rangeInfo;
                iss >> rangeInfo;
                
                if (rangeInfo.size() > 2 && rangeInfo.front() == '[' && rangeInfo.back() == ']') {
                    std::string minMax = rangeInfo.substr(1, rangeInfo.size() - 2);
                    size_t pipePos = minMax.find("|");
                    if (pipePos != std::string::npos) {
                        try {
                            sig.min = std::stod(minMax.substr(0, pipePos));
                            sig.max = std::stod(minMax.substr(pipePos + 1));
                        } catch (const std::exception& e) {
                            std::cerr << "Error parsing min/max: " << minMax << " - " << e.what() << std::endl;
                            sig.min = 0.0;
                            sig.max = 0.0;
                        }
                    }
                }
                
                // Extract unit (in quotes)
                std::string unitInfo;
                iss >> unitInfo;
                
                if (unitInfo.size() > 2 && unitInfo.front() == '"' && unitInfo.back() == '"') {
                    sig.unit = unitInfo.substr(1, unitInfo.size() - 2);
                }
                
                // Attach signal to the last message parsed
                if (!messages.empty()) {
                    messages.back().signals.push_back(sig);
                } else {
                    std::cerr << "Warning: Signal found but no message to attach to: " << sig.name << std::endl;
                }
            }
        }
    }
    infile.close();
}

// Display all parsed messages and their signals.
void listMessages() {
    std::cout << "\nParsed CAN Messages:\n";
    for (size_t i = 0; i < messages.size(); i++) {
        std::cout << i << ": ID " << messages[i].id 
                  << " | Name: " << messages[i].name 
                  << " | Length: " << messages[i].length << "\n";
        for (size_t j = 0; j < messages[i].signals.size(); j++) {
            const auto &s = messages[i].signals[j];
            std::cout << "\tSignal " << j << ": " << s.name 
                      << " [Start: " << s.startBit 
                      << ", Length: " << s.length 
                      << ", Endian: " << (s.littleEndian ? "Little" : "Big")
                      << ", Factor: " << s.factor 
                      << ", Offset: " << s.offset 
                      << ", Range: (" << s.min << " to " << s.max << ")"
                      << ", Unit: " << s.unit << "]\n";
        }
    }
}

// Allow a user to modify a signal parameter (for example, the scaling factor)
void modifyMessage() {
    std::cout << "\nEnter the message index to modify: ";
    int idx;
    std::cin >> idx;
    if (idx < 0 || idx >= static_cast<int>(messages.size())) {
        std::cout << "Invalid message index.\n";
        return;
    }
    auto &msg = messages[idx];
    std::cout << "Modifying message: ID " << msg.id << " Name: " << msg.name << "\n";
    
    // List available signals in the selected message.
    for (size_t i = 0; i < msg.signals.size(); i++) {
        const auto &s = msg.signals[i];
        std::cout << i << ": " << s.name 
                  << " (Current factor: " << s.factor << ")\n";
    }
    
    std::cout << "Enter signal index to modify: ";
    int sigIdx;
    std::cin >> sigIdx;
    if (sigIdx < 0 || sigIdx >= static_cast<int>(msg.signals.size())) {
        std::cout << "Invalid signal index.\n";
        return;
    }
    auto &sig = msg.signals[sigIdx];
    std::cout << "Enter new scaling factor for signal " << sig.name << ": ";
    double newFactor;
    std::cin >> newFactor;
    sig.factor = newFactor;
    std::cout << "Updated " << sig.name << " factor to " << sig.factor << "\n";
}

// Export the current parsed messages and signals back to a DBC file
void exportToDBC(const std::string& filename) {
    std::ofstream outfile(filename.c_str());
    if (!outfile) {
        std::cerr << "Error opening file " << filename << " for writing.\n";
        return;
    }
    
    // Write header
    outfile << "VERSION \"\"\n\n";
    outfile << "NS_ :\n";
    outfile << "\tNS_DESC_\n";
    outfile << "\tCM_\n";
    outfile << "\tBA_DEF_\n";
    outfile << "\tBA_\n";
    outfile << "\tVAL_\n";
    outfile << "\tCAT_DEF_\n";
    outfile << "\tCAT_\n";
    outfile << "\tFILTER\n";
    outfile << "\tBA_DEF_DEF_\n";
    outfile << "\tEV_DATA_\n";
    outfile << "\tENVVAR_DATA_\n";
    outfile << "\tSGTYPE_\n";
    outfile << "\tSGTYPE_VAL_\n";
    outfile << "\tBA_DEF_SGTYPE_\n";
    outfile << "\tBA_SGTYPE_\n";
    outfile << "\tSIG_TYPE_REF_\n";
    outfile << "\tVAL_TABLE_\n";
    outfile << "\tSIG_GROUP_\n";
    outfile << "\tSIG_VALTYPE_\n";
    outfile << "\tSIGTYPE_VALTYPE_\n";
    outfile << "\tBO_TX_BU_\n";
    outfile << "\tBA_DEF_REL_\n";
    outfile << "\tBA_REL_\n";
    outfile << "\tBA_DEF_DEF_REL_\n";
    outfile << "\tBU_SG_REL_\n";
    outfile << "\tBU_EV_REL_\n";
    outfile << "\tBU_BO_REL_\n";
    outfile << "\tSG_MUL_VAL_\n\n";
    outfile << "BS_:\n\n";
    outfile << "BU_: Vector__XXX\n\n";
    
    // Write messages and signals
    for (const auto& msg : messages) {
        outfile << "BO_ " << msg.id << " " << msg.name << ": " << msg.length << " Vector__XXX\n";
        
        for (const auto& sig : msg.signals) {
            std::string endianSign = sig.littleEndian ? "1+" : "0+";
            outfile << " SG_ " << sig.name << " : " 
                    << sig.startBit << "|" << sig.length << "@" << endianSign << " "
                    << "(" << sig.factor << "," << sig.offset << ") "
                    << "[" << sig.min << "|" << sig.max << "] "
                    << "\"" << sig.unit << "\" Vector__XXX\n";
        }
    }
    
    outfile.close();
    std::cout << "Exported to " << filename << " successfully.\n";
}

int main() {
    std::string filename;
    std::cout << "Enter DBC file name (e.g., CSS-Electronics-ISOBUS-demo.dbc): ";
    std::cin >> filename;
    
    parseDBC(filename);
    if (messages.empty()) {
        std::cout << "No messages found. Check the file format.\n";
        return 1;
    }
    
    // Simple interactive menu.
    while (true) {
        std::cout << "\nMenu:\n"
                  << "1. List CAN Messages\n"
                  << "2. Modify a Signal Parameter\n"
                  << "3. Display DBC File Contents\n"
                  << "4. Export to DBC File\n"
                  << "5. Exit\n"
                  << "Choose an option: ";
        int choice;
        std::cin >> choice;
        if (choice == 1) {
            listMessages();
        } else if (choice == 2) {
            modifyMessage();
        } else if (choice == 3) {
            displayDBCFileContents(filename);
        } else if (choice == 4) {
            std::string outputFile;
            std::cout << "Enter output DBC filename: ";
            std::cin >> outputFile;
            exportToDBC(outputFile);
        } else if (choice == 5) {
            break;
        } else {
            std::cout << "Invalid option.\n";
        }
    }
    return 0;
}