#Util lib.
import Util

#RandomX lib.
import mc_randomx

#BLS lib.
import mc_bls

#Meros RPC lib.
import MerosRPC

#OS standard lib.
import os

#Locks standard lib.
import locks

#Async standard lib.
import asyncdispatch

#String utils standard lib.
import strutils

#JSON standard lib.
import json

var
    #Connect to the Meros Node.
    rpc: MerosRPC = waitFor newMerosRPC()
    #Lock for using the RPC.
    rpcLock: Lock

    #Private Key.
    privateKey: PrivateKey

    #ID.
    id: int
    #Header.
    header: string
    #Body.
    body: string

    #Current Difficulty.
    difficulty: string

    #RandomX VM.
    key: string = ""
    flags: RandomXFlags = getFlags()
    cache: RandomXCache = allocCache(flags)
    vm: RandomXVM

vm = createVM(flags, cache, nil)

#If there are params, load them.
if paramCount() > 0:
    privateKey = newPrivateKey(parseHexStr(paramStr(1)))
#Else, create a new wallet to mine to.
else:
    echo "No wallet was passed in. Please run this command with a BLS Seed (in hex format) after it."
    quit()

#Acquire the RPC.
proc acquireRPC() {.async.} =
    #Acquire the RPC lock.
    while not tryAcquire(rpcLock):
        #While we can't acquire it, allow other async processes to run.
        await sleepAsync(1)

#Release the RPC.
proc releaseRPC() =
    release(rpcLock)

#Reset all data.
#This is used when someone else mines a Block or we publish an invalid one.
proc reset() {.async.} =
    #Acquire the RPC.
    await acquireRPC()

    #Get the Block template.
    var blockTemplate: JSONNode = await rpc.merit.getBlockTemplate(privateKey.toPublicKey().serialize())
    id = blockTemplate["id"].getInt()
    if key != blockTemplate["key"].getStr():
        key = parseHexStr(blockTemplate["key"].getStr())
        cache.init(key)
        vm.setCache(cache)
    header = parseHexStr(blockTemplate["header"].getStr())
    body = parseHexStr(blockTemplate["body"].getStr())

    #Get the difficulty.
    difficulty = await rpc.merit.getDifficulty()

    #Release the RPC.
    releaseRPC()

#Check for Verifications.
proc checkup() {.async.} =
    while true:
        #Run every thirty seconds.
        await sleepAsync(30000)

        #Update the template/difficulty.
        await reset()

#Mine.
proc mine(
    startProof: int
) {.async.} =
    #Mine the chain.
    var
        proof: int = startProof
        hash: string
        signature: Signature
    while true:
        #Mine the Block.
        hash = vm.hash(header & proof.toBinary(4))
        signature = privateKey.sign(hash)
        hash = vm.hash(hash & signature.serialize())

        if hash.lessThan(difficulty):
            #Allow checkup to run.
            await sleepAsync(1)

            #Increment the proof.
            inc(proof)

            #Continue.
            continue

        #Publish the block.
        try:
            await acquireRPC()
            await rpc.merit.publishBlock(id, header & proof.toBinary(4) & signature.serialize() & body)
            #Print that we mined a block.
            echo "Mined Block."
        except Exception as e:
            echo "Block we attempted to publish was rejected: " & e.msg
        finally:
            #Make sure we release the RPC.
            releaseRPC()

        #Since we either published a valid Block, or thought we did, reset.
        await reset()

#Reset so we have data to mine with.
waitFor reset()

#Start the checkup proc.
asyncCheck checkup()

#Start mining.
asyncCheck mine(0)

#Run forever.
runForever()
