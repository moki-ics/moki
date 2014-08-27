import socket
import sys
import struct

# Imported from Digital Bond's Basecamp Website
# Codesys-transfer.py, Copyright 2012 Digital Bond, Inc
# All praise to be attributed to Dale Peterson <peterson@digitalbond.com>
# All bugs and gripes to be attributed to K. Reid Wightman <krwightm@gmail.com>

# Takes integer, returns endian-word
def little_word(val):
    packed = struct.pack('<h', val)
    return packed

def recv_file2(host, port, lfilename, rfilename):
    # I have yet to encounter a codesys device that sends
    # more than 1024 bytes in a frame, so this should be
    # safe...if not try and adjust this upwards    
    BUFFER_SIZE = 1024
    BLOCK_SIZE = 1024
    # This is just some stupid initialization frame
    M1 = "\xbb\xbb\x01\x00\x00\x00\x01"
    # This is another stupid initialization frame.  It might not
    # even be necessary, but sending it works so why change it?
    M2 = "\xbb\xbb\x02\x00\x00\x00\x51\x10"
    s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    s.connect((host, port))
    # Send the first initialization frame
    s.send(M1)
    data = s.recv(BUFFER_SIZE)
    # Send the second
    s.send(M2)
    data = s.recv(BUFFER_SIZE)
    # This is the 'read request' frame
    # I don't know the meaning of all of the zero bytes, but basically it
    # is a double-wrapped protocol.  It has an outer length field, 4 bytes longer
    # then the payload, and an inner length field, which is the payload size
    # The 'read request' part is probably the \x23\x10\x00\x00\x31\x00 bits
    M4 = lambda x: "\xcc\xcc\x01\x00" + little_word(len(rfilename)+1+4) + "\x00"*10 + "\x01\x00\x00\x00" + "\x23\x10\x00\x00\x31\x00" + little_word(len(rfilename) + 1) + rfilename + "\x00"
    # Send our read request.  The first response frame will be file contents.
    # I don't handle a noneexistant file, so this utility will hang if the
    # file doesn't exist.
    s.send(M4(rfilename))
    done = False
    filedata = ""
    blocknum = 0
    bytesreceived = 0
    while done != True:
        data = s.recv(BUFFER_SIZE)
        if data[0:2] != "\xcc\xcc":
            # Sometimes controllers send these weird packets that start
            # "\x66\x66".  I have no idea what they mean, but we wave them away
            # with this packet
            Resp = "\x66\x66\x01\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x01\x00\x00\x00\x06\x00\x00\x00"
            s.send(Resp)
            continue
        # byte 26 (0-offset) is (I guess) a byte meaning 'more packets follow'
        # when the byte is 0, it means this is the last block of the transfer
        if data[26] == "\x00":
            print "--> Last block!"
            done = True
        blocknum += 1
        filedata += data[30:] # note: the data block does have two length fields at offsets 4 and 28 (little-endian words) but I ignore them
        print "Received block ", blocknum, " total bytes so far ", len(filedata)
        print "Debug: --> ",
        for byte in data[30:]:
            print hex(ord(byte)),
        print 
        if done != True:
            # I found that sending these requests between blocks is a good idea.
            # It might not be necessary, though...
            # It's identical to the 'Resp' variable above.  
            M5 = "\x66\x66\x01" + "\x00" * 13 + "\x01\x00\x00\x00\x06\00\x00\x00"
            s.send(M5)
            resp = s.recv(BUFFER_SIZE)
            # This is the actual request meaning 'the last block you sent was okay, send the next one'
            M6 = "\xcc\xcc\x01\x00\x01\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x01\x00\x00\x00\x23\x01\x00\x00\x32"
            s.send(M6)
            rep = s.recv(BUFFER_SIZE)
    s.close()
    # Finally write the fruits of our labour out to local disk
    outfile = open(lfilename, 'rb')
    outfile.write(filedata)
    outfile.close()


def send_file(host, port, lfilename, rfilename):  
    BUFFER_SIZE = 1024
    BLOCK_SIZE = 1024
    # See recv_file2 for explanations of these first frames
    M1 = "\xbb\xbb\x01\x00\x00\x00\x01"
    M2 = "\xbb\xbb\x02\x00\x00\x00\x51\x10"
    # first block
    # May want to look for buffer overflows here in things like file length, packet length, etc.
    # Applying packet structure above: BBBB, Packet length, options, command (0x2f, 0x01), 0x00 is a null terminator?
    M3 = lambda x, y: "\xbb\xbb" + struct.pack('<h', len(x) + len(y) + 8) + "\x00\x00\x2f\x01\x00" + struct.pack('>h', len(x) + len(y) + 2) + "\x00" + x + "\x00\xcd" + y
    # continuation block (block 2..n-1)
    # The last bytes before the data "\x00\x04" are actually the length of the continuation block
    # 1024 bytes in the normal case (little-endian)
    # Note \x00\x04 is the payload size (little-endian payload == 1024 byte blocks).
    # May want to look for buffer overflows here
    # M4 = lambda x: "\xbb\xbb\x04\x04\x00\x00\x30\x01\x00\x04" + x
    M4 = lambda x: "\xbb\xbb" + struct.pack('<h', len(x) + 4) + "\x00\x00\x30\x01" + struct.pack('<h', len(x)) + x
    #                                                                         ^^^ More blocks coming
    # last block.  Again the last two bytes are the length of the block.
    # So we need to calculate these, really.
    # Note the byte position 7 (0-offset) is 0x00 in the last block, versus 0x01 in
    # normal blocks.
    M5 = lambda x: "\xbb\xbb" + struct.pack('<h', len(x) + 4) + "\x00\x00\x30\x00" + struct.pack('<h', len(x)) + x
    #                                                                         ^^^ This is the last block
    # Read in the contents of localfile first
    lfile = open(lfilename, 'rb')
    filedata = lfile.read()
    lfile.close()
    # Calculate the number of full blocks we'll be sending
    fullblocks = len(filedata) / BLOCK_SIZE
    # I am a horrible, horrible person
    lastblocksize = len(filedata) - (fullblocks * BLOCK_SIZE)
    if lastblocksize == 0:
        fullblocks = fullblocks - 1
        lastblocksize = 1024

    # Hack all the codesys:
    # connect to the server
    s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    s.connect((host, port))
    # Send the first block
    s.send(M1)
    data = s.recv(BUFFER_SIZE)
    # and the primer
    s.send(M2)
    data = s.recv(BUFFER_SIZE)
    # and the filename + first block
    # For some reason the protocol sends data along with the filename in block 1...
    # print "Debug: sending initial block of " + str(len(filedata[0:BLOCK_SIZE]))
    payload = M3(rfilename, filedata[0:BLOCK_SIZE])
    s.send(payload)
    data = s.recv(BUFFER_SIZE)
    # Send the rest of the full-sized blocks
    for i in range(1, fullblocks):
        # print "Debug: sending block " + str(i) + ", size: " + str(len(filedata[i*BLOCK_SIZE:(i+1)*BLOCK_SIZE]))
        s.send(M4(filedata[i*BLOCK_SIZE:(i+1)*BLOCK_SIZE]))
        data = s.recv(BUFFER_SIZE)
    # Totally stupid python trick.  If range() above had no elements, then i is null...
    try:
        i = i + 1
    except:
        print "Debug: Sending lone block: ", filedata[0:]
        s.send(M5(filedata[0:]))
        data = s.recv(BUFFER_SIZE)
        print "Debug: Only one block, done!"
        return
    print "Debug: sending last block, size: " + str(len(filedata[i*BLOCK_SIZE:]))
    s.send(M5(filedata[i*BLOCK_SIZE:]))
    data = s.recv(BUFFER_SIZE)
    print "Done!  Maybe :)."
    s.close()
    return

def send_logic(host, port, lfilename, rlogicfilename, rchecksumname):  
    BUFFER_SIZE = 1024
    BLOCK_SIZE = 1024
    # See recv_file2 for explanations of these first frames
    M1 = "\xbb\xbb\x01\x00\x00\x00\x01"
    M2 = "\xbb\xbb\x02\x00\x00\x00\x51\x10"
    # first block
    # May want to look for buffer overflows here in things like file length, packet length, etc.
    # Applying packet structure above: BBBB, Packet length, options, command (0x2f, 0x01), 0x00 is a null terminator?
    M3 = lambda x, y: "\xbb\xbb" + struct.pack('<h', len(x) + len(y) + 8) + "\x00\x00\x2f\x01\x00" + struct.pack('>h', len(x) + len(y) + 2) + "\x00" + x + "\x00\xcd" + y
    # continuation block (block 2..n-1)
    # The last bytes before the data "\x00\x04" are actually the length of the continuation block
    # 1024 bytes in the normal case (little-endian)
    # Note \x00\x04 is the payload size (little-endian payload == 1024 byte blocks).
    # May want to look for buffer overflows here
    # M4 = lambda x: "\xbb\xbb\x04\x04\x00\x00\x30\x01\x00\x04" + x
    M4 = lambda x: "\xbb\xbb" + struct.pack('<h', len(x) + 4) + "\x00\x00\x30\x01" + struct.pack('<h', len(x)) + x
    #                                                                         ^^^ More blocks coming
    # last block.  Again the last two bytes are the length of the block.
    # So we need to calculate these, really.
    # Note the byte position 7 (0-offset) is 0x00 in the last block, versus 0x01 in
    # normal blocks.
    M5 = lambda x: "\xbb\xbb" + struct.pack('<h', len(x) + 4) + "\x00\x00\x30\x00" + struct.pack('<h', len(x)) + x
    #                                                                         ^^^ This is the last block
    # Read in the contents of localfile first
    lfile = open(lfilename, 'rb')
    logicfiledata = lfile.read()
    lfile.close()
    checksum = 0x00
    for byte in logicfiledata:
        checksum = checksum + ord(byte)
    checksumdata = struct.pack('<L', checksum)
    for filedata in [checksumdata, logicfiledata]:
        i = None # Stupid 'for' trick
        # Stupid, ohwell
        if filedata == logicfiledata:
            print "Debug: Sending logic file"
            rfilename = rlogicfilename
        else:
            print "Debug: Sending checksum"
            rfilename = rchecksumname
        # Calculate the number of full blocks we'll be sending
        fullblocks = len(filedata) / BLOCK_SIZE
        print "Debug: ", fullblocks, " full blocks, ", len(filedata), " total bytes"
        # I am a horrible, horrible person
        lastblocksize = len(filedata) - (fullblocks * BLOCK_SIZE)
        if lastblocksize == 0:
            fullblocks = fullblocks - 1
            lastblocksize = 1024

        # Hack all the codesys:
        # connect to the server
        s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        s.connect((host, port))
        # Send the first block
        s.send(M1)
        data = s.recv(BUFFER_SIZE)
        # and the primer
        s.send(M2)
        data = s.recv(BUFFER_SIZE)
        # and the filename + first block
        # For some reason the protocol sends data along with the filename in block 1...
        # print "Debug: sending initial block of " + str(len(filedata[0:BLOCK_SIZE]))
        payload = M3(rfilename, filedata[0:BLOCK_SIZE])
        s.send(payload)
        data = s.recv(BUFFER_SIZE)
        # Send the rest of the full-sized blocks
        for i in range(1, fullblocks):
            # print "Debug: sending block " + str(i) + ", size: " + str(len(filedata[i*BLOCK_SIZE:(i+1)*BLOCK_SIZE]))
            s.send(M4(filedata[i*BLOCK_SIZE:(i+1)*BLOCK_SIZE]))
            data = s.recv(BUFFER_SIZE)
        # Totally stupid python trick.  If range() above had no elements, then i is null...
        try:
            i = i + 1
        except:
            print "Debug: Sending lone block: ",
            for byte in filedata[0:]:
                print hex(ord(byte))
            print
            s.send(M5(filedata[0:]))
            data = s.recv(BUFFER_SIZE)
            print "Debug: Only one block, done!"
            s.close()
            #return
            continue # to next file
        print "Debug: sending last block, size: " + str(len(filedata[i*BLOCK_SIZE:]))
        s.send(M5(filedata[i*BLOCK_SIZE:]))
        data = s.recv(BUFFER_SIZE)
        print "Done!  Maybe...next file! :)."
    s.close()
    return

if len(sys.argv) < 5:
    print "Usage: " + sys.argv[0] + " <mode> <ip> <port> <local filename> <remote filename>"
    exit(1)

if sys.argv[1] == "send":
    send_file(sys.argv[2], int(sys.argv[3]), sys.argv[4], sys.argv[5])
elif sys.argv[1] == "recv":
    recv_file2(sys.argv[2], int(sys.argv[3]), sys.argv[4], sys.argv[5])
elif sys.argv[1] == "sendlogic":
    if len(sys.argv) < 6:
        print "Usage: " + sys.argv[0] + " <mode> <ip> <port> <local filename> <remote filename> <checksum name>"
        exit(1)
    send_logic(sys.argv[2], int(sys.argv[3]), sys.argv[4], sys.argv[5], sys.argv[6])
else:
    print "Usage: " + sys.argv[0] + " <mode> <ip> <port> <local filename> <remote filename> <optional checksum name>"
    print " <mode> ::= send | recv | sendlogic (note sendlogic sends two files, please specify the checksum name)"
    exit(1)
