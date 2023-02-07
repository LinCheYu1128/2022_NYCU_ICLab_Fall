#include <iostream>
#include <vector>
#include <random>
#include <fstream>
#include <stdlib.h>
#include <time.h> 
#include <iomanip>
#include <cmath>
#include <algorithm>
using namespace std;
// global variable
vector<vector< vector <int> >>x_matrix(16,vector<vector<int>>(8,vector<int>(8,0)));
vector<vector< vector <int> >>w_matrix(16,vector<vector<int>>(8,vector<int>(8,0)));
vector<vector< vector <int> >>y_matrix(16,vector<vector<int>>(8,vector<int>(8,0)));
vector<vector <int>>out_matrix(16,vector<int>(15,0));

vector <int> x_index(16,0);
vector <int> w_index(16,0);

int img_size;
int out_size;

int Rand(int n)
{
    return rand() % n ;
}

int main(){
    ofstream OutFile_input("input.txt");
    ofstream OutFile_output("output.txt");
    srand(time(NULL));
    int patcount = 100;
    OutFile_input << patcount << endl;
    //int range_max = 32767;
    int range_max = 63;
    //int range_min = -32768;
    int range_min = -64;
    for(int pat=0;pat<patcount;pat++){
        // img size
        img_size = rand()%3;
        if(img_size == 0){
            img_size = 2;
            out_size = 3;
        } 
        else if(img_size == 1){
            img_size = 4;
            out_size = 7;
        } 
        else{
            img_size = 8;
            out_size = 15;
        }  
            
        OutFile_input << img_size << endl;
        
        // matrix
        for(int k=0; k<16; k++){
            for(int i=0;i<img_size;i=i+1){
                for(int j=0;j<img_size;j=j+1){
                    x_matrix[k][i][j] = rand() % (range_max-range_min+1)+range_min;
                    OutFile_input << setw(3) << x_matrix[k][i][j] << " ";
                }
                OutFile_input << endl;
            }
            OutFile_input << endl;
        }
        for(int k=0; k<16; k++){
            for(int i=0;i<img_size;i=i+1){
                for(int j=0;j<img_size;j=j+1){
                    w_matrix[k][i][j] = rand() % (range_max-range_min+1)+range_min;
                    OutFile_input << setw(3) << w_matrix[k][i][j] << " ";
                }
                OutFile_input << endl;
            }
            OutFile_input << endl;
        }

        // mul oreder
        for(int k=0; k<16; k++){
            x_index[k] = k;
            w_index[k] = 15-k;
        }
        random_shuffle(x_index.begin(),x_index.end(),Rand);
        random_shuffle(w_index.begin(),w_index.end(),Rand);
        for(int k=0; k<16; k++){
            OutFile_input << setw(3) << x_index[k] << " ";
        }
        OutFile_input << endl;
        for(int k=0; k<16; k++){
            OutFile_input << setw(3) << w_index[k] << " ";
        }
        OutFile_input << endl << endl;

        //  cal answer
        for(int l=0; l<16; l++){
            for (int i = 0; i < img_size; i++) {
                for (int j = 0; j < img_size; j++) {
                    y_matrix[l][i][j] = 0;
                    for (int k = 0; k < img_size; k++) {
                        y_matrix[l][i][j] += x_matrix[x_index[l]][i][k] * w_matrix[w_index[l]][k][j];
                    }
                    // cout << setw(6) << y_matrix[l][i][j] << " ";
                }
                // cout << endl;
            }
            // cout << endl;
        }

        // cal output
        OutFile_output << out_size << endl;
        for(int l=0; l<16; l++){
            for(int i=0; i<out_size; i++){
                out_matrix[l][i] = 0;
            }
            for (int i = 0; i < img_size; i++) {
                for (int j = 0; j < img_size; j++) {
                    out_matrix[l][i+j] += y_matrix[l][i][j];
                    // cout << setw(6) << y_matrix[l][i][j] << " ";
                }
                // cout << endl;
            }
            // cout << endl;
            for(int i=0; i<out_size; i++){
                OutFile_output << setw(6) << out_matrix[l][i] << " ";
            }
            OutFile_output << endl;
        }
    }
    
    return 0;
}