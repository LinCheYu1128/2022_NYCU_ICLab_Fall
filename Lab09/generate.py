import random as rd
from secrets import choice

CUST_STATUS = {"VIP": 3, "Normal": 1, "None": 0}

fout = open("./dram.dat", "w")


restuarant_info_array = []

def DRAM_data():
    # restuarant_info
    for i in range(0, 256):
        busy_or_not = rd.randint(0,5)
        if busy_or_not>4:
            total_order = rd.randint(0,100)
            food1 = rd.randint(0, total_order)
            food2 = rd.randint(0, (total_order - food1))
            food3 = rd.randint(0, (total_order - food1 - food2))
        elif busy_or_not>2:
            total_order = rd.randint(0,60)
            food1 = 20
            food2 = 20
            food3 = 20
        else:
            total_order = rd.randint(0,60)
            food1 = 0
            food2 = 0
            food3 = 0
        restuarant_info = [total_order, food1, food2, food3]
        restuarant_info_array.append(restuarant_info)

    print("size ", len(restuarant_info_array))
    for addr in range(0x10000, 0x107fc, 8):

        # restuarant info
        id = int((addr-65536)/8)
        # print(int(id)) 
        fout.write('@' + format(addr, 'x') + '\n')

        fout.write('{:0>2x}'.format(restuarant_info_array[id][0], 'x') + ' ')
        fout.write('{:0>2x}'.format(restuarant_info_array[id][1], 'x') + ' ')
        fout.write('{:0>2x}'.format(restuarant_info_array[id][2], 'x') + ' ')
        fout.write('{:0>2x}'.format(restuarant_info_array[id][3], 'x') + '\n')

        # deliver info
        fout.write('@' + format(addr + 4, 'x') + '\n')
        serving_num = rd.randint(0,2)
        if serving_num == 0:
            fout.write('{:0>2x}'.format(0, 'x') + ' ' + '{:0>2x}'.format(0, 'x') + ' ' + '{:0>2x}'.format(0, 'x') + ' ' + '{:0>2x}'.format(0, 'x') + '\n')
        elif serving_num == 1:
            customer_status = rd.choice(["VIP", "Normal"])
            restuarant_id = rd.randint(0,255)
            foodid = rd.randint(1,3)
            serving_of_food = rd.randint(1,15)

            data1 = CUST_STATUS[customer_status]*(2**6) + int(restuarant_id/4)
            fout.write('{:0>2x}'.format(data1, 'x') + ' ')
            data2 = (restuarant_id%4)*(2**6) + foodid*(2**4) + serving_of_food
            # print(data2, " ", restuarant_id, foodid, serving_of_food)
            fout.write('{:0>2x}'.format(data2, 'x') + ' ')
            fout.write('{:0>2x}'.format(0, 'x') + ' ' + '{:0>2x}'.format(0, 'x') + '\n')
        elif serving_num == 2:
            customer_status = "VIP"
            restuarant_id = rd.randint(0,255)
            foodid = rd.randint(1,3)
            serving_of_food = rd.randint(1,15)

            data1 = CUST_STATUS[customer_status]*(2**6) + int(restuarant_id/4)
            fout.write('{:0>2x}'.format(data1, 'x') + ' ')
            data2 = (restuarant_id%4)*(2**6) + foodid*(2**4) + serving_of_food
            # print(data2, " ", restuarant_id, foodid, serving_of_food)
            fout.write('{:0>2x}'.format(data2, 'x') + ' ')

            customer_status = "Normal"
            restuarant_id = rd.randint(0,255)
            foodid = rd.randint(1,3)
            serving_of_food = rd.randint(1,15)

            data1 = CUST_STATUS[customer_status]*(2**6) + int(restuarant_id/4)
            fout.write('{:0>2x}'.format(data1, 'x') + ' ')
            data2 = (restuarant_id%4)*(2**6) + foodid*(2**4) + serving_of_food
            # print(data2, " ", restuarant_id, foodid, serving_of_food)
            fout.write('{:0>2x}'.format(data2, 'x') + '\n')
        
DRAM_data()