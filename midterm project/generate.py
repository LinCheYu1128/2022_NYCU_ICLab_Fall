import random as rd
import math
from secrets import choice
import matplotlib.pyplot as plt

fout = open("./dram.dat", "w")
op_out = open("./op.txt", "w")
log_out = open("./log.txt", "w")

se_array = []
pic_array = []

def DRAM_data():
    # SE data
    for addr in range(0x30000, 0x303ff, 16):
        
        se = [[rd.randint(0,20) for x in range(4)] for y in range(4)]
        se_array.append(se)

        # print("no.",int((addr-0x30000)/16))
        for x in range(4):
            fout.write('@' + format(addr + 4*x, 'x') + '\n')
            for y in range(4):
                fout.write('{:0>2x}'.format(se[x][y], 'x') + ' ') 
                # print ('{0:>3}'.format(se[x][y]), end=" ") 
            fout.write('\n')
            # print()
    # test
    # print("size", len(se_array))
    # se1 = se_array[62]
    # for x in range(4):
    #     for y in range(4):
    #         print ('{0:>3}'.format(se1[x][y]), end=" ") 
    #     print()
     
    # PIC data
    for addr in range(0x40000, 0x4ffff, 4096):
        
        pic = [[rd.randint(100,200) for x in range(64)] for y in range(64)]
        pic_array.append(pic)

        # print("no.",int((addr-0x40000)/4096))
        for x in range(64):
            for y in range(16):
                fout.write('@' + format(addr + 64*x + 4*y, 'x') + '\n')
                for i in  range(4):
                    fout.write('{:0>2x}'.format(pic[x][4*y+i], 'x') + ' ') 
                    # print ('{0:>3}'.format(pic[x][y]), end=" ") 
                fout.write('\n')
            # print()
    # test
    # print("size", len(pic_array))
    # se1 = pic_array[15]
    # for x in range(64):
    #     for y in range(64):
    #         print ('{0:>3}'.format(se1[x][y]), end=" ") 
    #     print()

def ZERO_PAD(pic):
    zero_pic = [[0 for x in range(67)] for y in range(67)]
    for x in range(64):
        for y in range(64):
            zero_pic[x][y] = pic[x][y]
    return zero_pic

def EROSION(se, pic):
    # zero padding
    zero_pic = ZERO_PAD(pic)

    for x in range(4):
        for y in range(4):
            log_out.write('{:0>2}'.format(se[x][y]) + ' ')
        log_out.write('\n')

    for x in range(64):
        for y in range(64):
            log_out.write('{:0>3}'.format(pic[x][y]) + ' ')
        log_out.write('\n')
        
    for x in range(64):
        for y in range(64):
            temp = 255
            for xi in range(4):
                for yi in range(4):
                    if (zero_pic[x+xi][y+yi] - se[xi][yi])<temp:
                        temp = zero_pic[x+xi][y+yi] - se[xi][yi]
            if temp < 0:
                pic[x][y] = 0
            else:
                pic[x][y] = temp
            op_out.write('{:0>2x}'.format(pic[x][y]) + ' ')
        op_out.write('\n')
    return pic

def DILATION(se, pic):
    # zero padding
    zero_pic = ZERO_PAD(pic)
    # Do symmetry
    se_s = [[0 for x in range(4)] for y in range(4)]

    for x in range(4):
        for y in range(4):
            se_s[x][y] = se[3-x][3-y]
            log_out.write('{:0>2}'.format(se_s[x][y]) + ' ')
        log_out.write('\n')

    for x in range(64):
        for y in range(64):
            log_out.write('{:0>3}'.format(pic[x][y]) + ' ')
        log_out.write('\n')
        
    for x in range(64):
        for y in range(64):
            temp = 0
            for xi in range(4):
                for yi in range(4):
                    if (zero_pic[x+xi][y+yi] + se_s[xi][yi])>temp:
                        temp = zero_pic[x+xi][y+yi] + se_s[xi][yi]
            pic[x][y] = temp
            if pic[x][y] > 255:
                pic[x][y] = 255
            op_out.write('{:0>2x}'.format(pic[x][y]) + ' ')
        op_out.write('\n')
    return pic
    
def HIST(se, pic):
    pdf = [0 for i in range(256)]
    cdf = [0 for i in range(256)]
    for x in range(64):
        for y in range(64):
            pdf[pic[x][y]] = pdf[pic[x][y]] + 1
    
    cdfmin = 0
    label = [i for i in range(256)]
    for i in range(256):
        if i == 0:
            cdf[i] = pdf[i]
        else:
            cdf[i] = cdf[i-1] + pdf[i]
        if cdfmin == 0 and pdf[i] != 0:
            cdfmin = cdf[i]
        # print(i,"->",pdf[i]," ",cdf[i])
    # print(cdfmin)

    # plt.bar(label, pdf)
    # plt.show()
    
    for x in range(64):
        for y in range(64):
            if pic[x][y] != 0:
                pic[x][y] = int((cdf[pic[x][y]] - cdfmin)*255/(4096-cdfmin))
            if pic[x][y] > 255:
                pic[x][y] = 255
            # print ('{0:>3}'.format(pic[x][y]), end=" ")
            op_out.write('{:0>2x}'.format(pic[x][y]) + ' ')
        # print()
        op_out.write('\n')
    
    return pic


def RANDOM_OP():
    PATNUM = 16
    op_out.write(format(PATNUM) + '\n')
    
    for pat in range(PATNUM):
        op = rd.randint(0,2)
        op_out.write(format(op) + ' ')
        se_no = rd.randint(0,63)
        op_out.write(format(se_no) + ' ')
        pic_no = rd.randint(0,15)
        op_out.write(format(pic_no) + '\n')

        se = se_array[se_no]
        pic = pic_array[pic_no]
        if op == 0:
            EROSION(se, pic)
        elif op == 1:
            DILATION(se, pic)
        else:   
            pic = HIST(se, pic)

        # writeback
        pic_array[pic_no] = pic
        # for x in range(64):
        #     for y in range(64):
        #         print('{:0>2x}'.format(pic[x][y]), end=" ")
        #     print()
            


DRAM_data()
RANDOM_OP()
