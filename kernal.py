import sys
from IPython import embed

w0 = (int("0A89E", 16), int("092D5", 16), int("06D43", 16), \
      int("01004", 16), int("F8F71", 16), int("F6E54", 16), \
      int("FA6D7", 16), int("FC834", 16), int("FAC19", 16))
w1 = (int("FDB55", 16), int("02992", 16), int("FC994", 16), \
      int("050FD", 16), int("02F20", 16), int("0202D", 16), \
      int("03BD7", 16), int("FD369", 16), int("05E68", 16))
weight = (w0, w1)
bias = (int("01310", 16), int("F7295", 16))

def realvalue (num) :
    return -1*(num & ((1<<19) -1) ) if ((num >> 19) & 1) else num

def nWaveFormat(nums, size=20) :
    result = str()
    idx = 0

    for num in reversed(nums) :
        temp = int(num)

        for _ in xrange(size >> 2) :
            if (idx & 3 == 0) and idx != 0 : result += '_'
            result += hex(temp & 15)[2:].upper()
            temp >>= 4
            idx += 1
    #print(result[::-1])
    
    return result[::-1]

if __name__ == "__main__":
    data = [int(sys.argv[i+1], 16) for i in range(9)]

    for i in [0,1] :
        print("kernal" + str(i))

        #step1
        mul_raw = [realvalue(data[j]) * realvalue(weight[i][j]) for j in range(9)]
        print("mul_raw " + nWaveFormat(mul_raw, 40))
        mul = [((mul_raw[j] >> 16) & ((1 << 20)-1)) + ((mul_raw[j]  >> 15) & 1 ) for j in range(9)]
        print("    mul " + nWaveFormat(mul))

        #step2
        s21 = bias[i] + mul[8] + mul[7] + mul[6]
        s20 =  mul[5] + mul[4] + mul[3] + mul[2]
        s2 = (s21, s20)
        print("     s2 " + nWaveFormat(s2))

        #step3
        total = s2[0] + s2[1] + mul[1] + mul[0]
        print("    sum " + nWaveFormat([total]))
        relu = 0 if ((total >> 19) & 1) else total
        print("   relu " + nWaveFormat([relu]) + "\n")


    

    #embed()