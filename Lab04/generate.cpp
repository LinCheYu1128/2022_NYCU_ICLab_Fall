#include<bits/stdc++.h>
#include <vector>
#include <random>
#include <fstream>
using namespace std;

ofstream OutFile("input.txt");
ofstream OutFile1("output.txt");

void printBinary(int n, int i){
    // Prints the binary representation
    // of a number n up to i-bits.
    int k;
    for (k = i - 1; k >= 0; k--) {
        if ((n >> k) & 1)
            OutFile << "1";
        else
            OutFile << "0";
    }
}
 
void printBinary1(int n, int i){
    // Prints the binary representation
    // of a number n up to i-bits.
    int k;
    for (k = i - 1; k >= 0; k--) {
        if ((n >> k) & 1)
            OutFile1 << "1";
        else
            OutFile1 << "0";
    }
}
typedef union {
    float f;
    struct{
        // Order is important.
        // Here the members of the union data structure
        // use the same memory (32 bits).
        // The ordering is taken
        // from the LSB to the MSB.
        unsigned int mantissa : 23;
        unsigned int exponent : 8;
        unsigned int sign : 1;
 
    } raw;
} myfloat;
 
// Function to convert real value
// to IEEE floating point representation
void printIEEE(myfloat var){
    // Prints the IEEE 754 representation
    // of a float value (32 bits)
    OutFile << var.raw.sign ;//<< "_";
    printBinary(var.raw.exponent, 8);
    // OutFile << "_";
    printBinary(var.raw.mantissa, 23);
    OutFile << "\n";
}

void printIEEE1(myfloat var){
    // Prints the IEEE 754 representation
    // of a float value (32 bits)
    cout << fixed << setprecision(6) << var.f << endl;
    OutFile1 << var.raw.sign ;//<< "_";
    printBinary1(var.raw.exponent, 8);
    // OutFile1 << "_";
    printBinary1(var.raw.mantissa, 23);
    OutFile1 << "\n";
}

unsigned int convertToInt(vector<unsigned int> arr, int low, int high){
    unsigned int f = 0, i;
    for (i = high; i >= low; i--) {
        f = f + arr[i] * pow(2, high - i);
    }
    return f;
}

float convert(vector<unsigned int> arr){
    myfloat var;
    
    // Convert the least significant
    // mantissa part (23 bits)
    // to corresponding decimal integer
    unsigned int f = convertToInt(arr, 9, 31);
 
    // Assign integer representation of mantissa
    var.raw.mantissa = f;
 
    // Convert the exponent part (8 bits)
    // to a corresponding decimal integer
    f = convertToInt(arr, 1, 8);
 
    // Assign integer representation
    // of the exponent
    var.raw.exponent = f;
 
    // Assign sign bit
    var.raw.sign = arr[0];
    // cout << "The float value of the given"
    //        " IEEE-754 representation is : \n";
    // cout << fixed << setprecision(6) << var.f <<endl;
    // cout << var.f <<endl;
    return var.f;
}

constexpr int FLOAT_MIN = -5;
constexpr int FLOAT_MAX = 5;
// Driver Code
int main(){

    vector<unsigned int> ieee = { 0,
            0, 1, 1, 1, 0, 1, 0, 0, 0, 0, 0,
            0, 0, 1, 1, 0, 0, 0, 1, 0, 0, 1,
            0, 0, 1, 1, 0, 1, 1, 1, 1 };
    
    // cout << convert(ieee) << endl;

    srand((unsigned)time(0));
    int PATNUM = 100;
    OutFile << PATNUM << endl;
    OutFile << endl;

    for(int pat = 0; pat<PATNUM; pat++){
        
        // decimal float number
        vector < vector<float>>dweight_u; 
        dweight_u.resize(3,vector<float>(3,0));
        vector < vector<float>>dweight_w; 
        dweight_w.resize(3,vector<float>(3,0));
        vector < vector<float>>dweight_v; 
        dweight_v.resize(3,vector<float>(3,0));
        vector < vector<float>>ddata_x; 
        ddata_x.resize(3,vector<float>(3,0));


        for(int i=0; i<3; i++){
            for(int j=0; j<3; j++){
                dweight_u[i][j] = FLOAT_MIN + (float)(rand()) / ((float)(RAND_MAX/(FLOAT_MAX - FLOAT_MIN)));
                myfloat var;
                var.f = dweight_u[i][j];
                printIEEE(var);
                // cout << fixed << setprecision(6) << dweight_u[i][j] << endl;
            }
        }
        OutFile << endl;
        for(int i=0; i<3; i++){
            for(int j=0; j<3; j++){
                dweight_w[i][j] = FLOAT_MIN + (float)(rand()) / ((float)(RAND_MAX/(FLOAT_MAX - FLOAT_MIN)));
                myfloat var;
                var.f = dweight_w[i][j];
                printIEEE(var);
                // cout << fixed << setprecision(6) << dweight_w[i][j] << endl;
            }
        }
        OutFile << endl;
        for(int i=0; i<3; i++){
            for(int j=0; j<3; j++){
                dweight_v[i][j] = FLOAT_MIN + (float)(rand()) / ((float)(RAND_MAX/(FLOAT_MAX - FLOAT_MIN)));
                myfloat var;
                var.f = dweight_v[i][j];
                printIEEE(var);
                // cout << fixed << setprecision(6) << dweight_v[i][j] << endl;
            }
        }
        OutFile << endl;
        for(int i=0; i<3; i++){
            for(int j=0; j<3; j++){
                ddata_x[i][j] = FLOAT_MIN + (float)(rand()) / ((float)(RAND_MAX/(FLOAT_MAX - FLOAT_MIN)));
                myfloat var;
                var.f = ddata_x[i][j];
                printIEEE(var);
                // cout << fixed << setprecision(6) << ddata_x[i][j] << endl;
            }
        }
        OutFile << endl;

        vector < vector<float>>h; h.resize(4,vector<float>(3,0));
        vector < vector<float>>output_y; output_y.resize(3,vector<float>(3,0));
        
        for(int i=0; i<3; i++){
            h[i+1][0] = (dweight_u[0][0]*ddata_x[i][0] + dweight_u[0][1]*ddata_x[i][1] + dweight_u[0][2]*ddata_x[i][2]) + 
                        (dweight_w[0][0]*      h[i][0] + dweight_w[0][1]*      h[i][1] + dweight_w[0][2]*      h[i][2]);
            h[i+1][0] = 1/(1+exp(-h[i+1][0]));

            h[i+1][1] = (dweight_u[1][0]*ddata_x[i][0] + dweight_u[1][1]*ddata_x[i][1] + dweight_u[1][2]*ddata_x[i][2]) + 
                        (dweight_w[1][0]*      h[i][0] + dweight_w[1][1]*      h[i][1] + dweight_w[1][2]*      h[i][2]);
            h[i+1][1] = 1/(1+exp(-h[i+1][1]));
                        
            h[i+1][2] = (dweight_u[2][0]*ddata_x[i][0] + dweight_u[2][1]*ddata_x[i][1] + dweight_u[2][2]*ddata_x[i][2]) + 
                        (dweight_w[2][0]*      h[i][0] + dweight_w[2][1]*      h[i][1] + dweight_w[2][2]*      h[i][2]);
            h[i+1][2] = 1/(1+exp(-h[i+1][2]));

            output_y[i][0] = (dweight_v[0][0]*h[i+1][0] + dweight_v[0][1]*h[i+1][1] + dweight_v[0][2]*h[i+1][2]);
            if(output_y[i][0]<0) output_y[i][0] = 0;
            output_y[i][1] = (dweight_v[1][0]*h[i+1][0] + dweight_v[1][1]*h[i+1][1] + dweight_v[1][2]*h[i+1][2]);
            if(output_y[i][1]<0) output_y[i][1] = 0;
            output_y[i][2] = (dweight_v[2][0]*h[i+1][0] + dweight_v[2][1]*h[i+1][1] + dweight_v[2][2]*h[i+1][2]);
            if(output_y[i][2]<0) output_y[i][2] = 0;
            cout << fixed << setprecision(6) << output_y[i][0] << " "<<output_y[i][1]<<" "<<output_y[i][2]<< endl;
            myfloat var;
            var.f = output_y[i][0];
            printIEEE1(var);
            var.f = output_y[i][1];
            printIEEE1(var);
            var.f = output_y[i][2];
            printIEEE1(var);
        }
        OutFile1 << endl;
    }
    return 0;
}
