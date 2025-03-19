#include<iostream>
#include<fstream>
#include<bitset>
#include<vector>

struct canMessageString {
    std::string messageSyntax;
    std::string signalSyntax;
};

struct canMessage {
    std::bitset<32> CAN_ID;
    std::string name;
    int length;
    std::string sender;
};

struct canSignal {
    std::string name;
    int bitStart;
    int length;
    bool littleEndian;
    int scale;
    int offset;
    int min;
    int max;
    std::string unit;
    std::string reciever;
};

void canPrint(std::string message);

int main() {
    std::ifstream inputfile("./CSS-Electronics-ISOBUS-demo.dbc");
    //std::ifstream inputfile("./CSS-Electronics-SAE-J1939-DEMO+.dbc");
    
    std::string line;
    std::vector<canMessageString> canMessageStrings;
    
    if (inputfile.is_open()) {
        // File operations
    } else {
        std::cerr << "Error opening file!" << std::endl;
    }

    bool readingFrame = false;
    while (getline(inputfile, line)) {
        line.pop_back();
        //std::cout << "{" << line << "}" << std::endl;
        //std::cout << "\tline.find(\"BO_\"): " << line.find("BO_") << std::endl;
        //std::cout << "\tline.size(): " << line.size() << std::endl;
        if (line.find("BO_") == 0) {
            //std::cout << "\tBO_ FOUND\n";
            //std::cout << line << std::endl;
            canPrint(line);
            canMessageString tempMessage;
            tempMessage.messageSyntax = line;
            canMessageStrings.push_back(tempMessage);
            readingFrame = true;
        }
        else if (readingFrame) {
            //std::cout << "readingFrame = true\n"; 
            //std::cout << "{Left Bracket}" << line << "{Right Bracket}" << std::endl;
            canPrint(line);
            int tempInt = canMessageStrings.size() - 1;
            canMessageStrings[tempInt].signalSyntax = line;
            readingFrame = false;
        }
    }

    //std::cout << "canMessageStrings.size(): " << canMessageStrings.size() << std::endl;


    for(int i = 0; i < canMessageStrings.size(); i++){
        //std::cout << "Template:\n";
        std::cout << canMessageStrings[i].messageSyntax << std::endl;
        std::cout << canMessageStrings[i].signalSyntax << std::endl;
    }
    
    inputfile.close();

    return 0;
}

void canPrint(std::string message) {
    int iter = 0;
    int end = 0;
    bool running = true;
    std::cout << "Message:\n"; 
    while (running) {
        if (message[iter] == ' ') {
            iter += 1;
        }
        end = message.find(' ', iter);
        if (end == std::string::npos) {
            running = false;
        }
        std::cout << "\t\"" << message.substr(iter, end-iter) << "\"" << std::endl;
        iter = end;
    }
}


void canMessageLoader(canMessage* Message) {
    int iter = 0;
    int end = 0; 
    
    // Skip First bit
    end = message.find(' ', iter);
    iter = end;
    
    // CAN_ID
    if (message[iter] == ' ') {
        iter += 1;
    }
    end = message.find(' ', iter);
    std::bitset<32> ID(message.substr(iter, end-iter));  
    Message.CAN_ID = ID;
    iter = end;

    // Name
    if (message[iter] == ' ') {
        iter += 1;
    }
    end = message.find(' ', iter);
    std::string name = message.substr(iter, (end-iter)-1);  
    Message.name = name;
    iter = end;

    // Name
    if (message[iter] == ' ') {
        iter += 1;
    }
    end = message.find(' ', iter);
    std::string name = message.substr(iter, end-iter);  
    Message.name = name;
    iter = end;

}

struct canMessage {
    std::bitset<32> CAN_ID;
    std::string name;
    int length;
    std::string sender;
};
