#include<iostream>
#include<bitset>

void demo();

int main() {
    demo();

    return 0;
}

void demo() {
    // This function here is to highlight two important tools that will make our lives easier: "Bitset" and "Bitshifting"
    // Bitset allows you to initialize a set of binary values
    // "<<" and ">>" allow you to perform bitwise operations on the set and shift all values left or right. Anything that we shift out of scope, is zero'd out.

    //std::bitset<4> bitString(31);
    std::bitset<8> bitString("11001010");

    std::cout << "Bit String 1: " << bitString << std::endl;
    std::cout << "Bit String 2: " << (bitString << 1) << std::endl;
    std::cout << "Bit String 3: " << (bitString << 1 >> 1) << std::endl;
    std::cout << "Bit String 4: " << (bitString << 2 >> 1) << std::endl;
    std::cout << "Bit String 5: " << (bitString << 2 >> 2) << std::endl;
    std::cout << "Bit String 6: " << (bitString >> 1) << std::endl;
    std::cout << "Bit String 7: " << (bitString >> 1 << 1) << std::endl;
    std::cout << "Bit String 7: " << (bitString >> 2 << 2) << std::endl;

    std::cout << std::endl;

    std::bitset<8> bitStringFull(511);
    std::cout << "Full String: " << bitStringFull << std::endl;
    std::cout << "Half String: " << (bitStringFull << 4 >> 4) << std::endl;
    std::cout << "Other Half String: " << (bitStringFull >> 4 << 4) << std::endl;
    std::cout << "Empty String: " << (bitStringFull << 8 >> 8) << std::endl;

    std::cout << std::endl;

    // We can even get fancy
    std::cout << "Numbers:\n";
    for (int i = 8; i >= 0; i--){
        std::cout << (bitStringFull << i >> i).to_ulong() << " ";
    }
    std::cout << std::endl;

    std::cout << std::endl;

    // Fancier
    std::cout << "More Numbers:\n";
    for (int i = 8; i >= 0; i--){
        std::cout << (bitStringFull << i >> i >> 7-i << 7-i).to_ulong() << " ";
    }
    std::cout << std::endl;

    // Delete this
    std::bitset<29+3> bitStringCAN(2364540158);
    std::cout << "bitStringCAN: " << bitStringCAN << std::endl;

}