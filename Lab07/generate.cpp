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

vector <int> card(52, 0);
vector <int> remain_card(13, 4);
// vector <int> player1(5, 0);
// vector <int> player2(5, 0);
int Rand(int n)
{
    return rand() % n ;
}

int main(){
    ofstream OutFile_input("input.txt");
    ofstream OutFile_output("output.txt");
    srand(time(NULL));
    int round = 100;
    int epoch = 5;
    int card_amount;
    for(int i=0; i<round; i++){
        // reset
        for(int j=0; j<13; j++){
            for(int k=0; k<4; k++){
                card[4*j+k] = j+1;
            }
        }
        for(int j=0; j<10; j++){
            if(j==0) remain_card[j] = 16;
            else remain_card[j] = 4;
        }
        random_shuffle(card.begin(),card.end(),Rand);
        card_amount = 52;
        int equal, pequal, exceed, pexceed;
        for(int j=0; j<epoch; j++){
            int player1 = 0;
            int player2 = 0;
            // give total 10 card
            for(int k=0; k<10; k++){
                OutFile_input << card[10*j+k] << " "; 
                // A J Q K
                if(card[10*j+k]>10){
                    remain_card[0] = remain_card[0] - 1;
                    if(k<5)
                        player1 ++;
                    else
                        player2 ++;
                }
                // 2 ~ 10
                else{
                    remain_card[card[10*j+k]-1] = remain_card[card[10*j+k]-1] - 1;
                    if(k<5)
                        player1 = player1 + card[10*j+k];
                    else
                        player2 = player2 + card[10*j+k];
                }
                card_amount -- ;
                if(k==2 || k==3 || k==7 || k==8){
                    if(k<5)
                        equal = 21 - player1;
                    else
                        equal = 21 - player2;
                    cout << "equal card = " << equal << " remain "<< remain_card[equal-1] << endl;
                    if(equal > 10 || equal<=0) pequal = 0;
                    else pequal = remain_card[equal-1]*100/card_amount ;
                    exceed = 0;
                    if(equal>10) pexceed = 0;
                    else if(equal<=0) pexceed = 100;
                    else{
                        for(int k=equal; k<10; k++){
                            exceed = exceed + remain_card[k];
                        }
                        cout << "exceed card = " << exceed << endl;
                        pexceed = exceed*100/card_amount;
                    } 
                    OutFile_output << pequal << " " << pexceed << endl;
                }
                // choose winner
                if(k==9){
                    if(player1>21 && player2>21){
                        OutFile_output << 0 << endl;
                    }
                    else if(player1==21 && player2==21){
                        OutFile_output << 0 << endl;
                    }
                    else if(player1>21){
                        OutFile_output << 3 << endl;
                    }
                    else if(player2>21){
                        OutFile_output << 2 << endl;
                    }
                    else if(player2>player1){
                        OutFile_output << 3 << endl;
                    }
                    else if(player1>player2){
                        OutFile_output << 2 << endl;
                    }
                    else{
                        OutFile_output << 0 << endl;
                    }
                    cout << "card amount" << card_amount << endl;
                    OutFile_input << endl;
                }
            }
                

            // test remain card
            for(int j=0; j<10; j++){
                cout << j+1 << " => "<< remain_card[j] << endl;
            }
        }
        

    }
    return 0;
}