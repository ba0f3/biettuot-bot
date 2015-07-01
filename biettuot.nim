import asyncdispatch
import httpclient
import streams
import htmlparser
import xmltree
import json
import q
from cgi import encodeUrl
import strutils
import math
import os

const

  TELEGRAM_BASE_URL = "https://api.telegram.org/bot" & TELEGRAM_TOKEN
  SEND_MESSAGE_URL = TELEGRAM_BASE_URL &  "/sendMessage"
  SEND_PHOTO_URL = TELEGRAM_BASE_URL & "/sendPhoto"
  GET_UPDATE_URL = TELEGRAM_BASE_URL &  "/getUpdates"
  
  WOLFRAM_URL = "http://api.wolframalpha.com/v2/query?appid=" & WOLFRAM_TOKEN & "&format=plaintext&input="
  
var
  lastUpdateId: BiggestInt = 0

randomize()
proc mktemp(len: int = 6): string =
  var charset {.global.} = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"

  var filename = newString(len)
  while true:
    for i in 0..len-1:
      filename[i] = charset[random(charset.len-1)]
    result = getTempDir() & filename
    if not result.existsFile:
      break

  
proc sendMessage(chatId: BiggestInt, text: string) {.inline.} =
  var data = newMultipartData()
  data["chat_id"] = $chatId
  data["text"] = text
  
  echo postContent(SEND_MESSAGE_URL, multipart=data)

proc search(chatId: BiggestInt, input: string) {.async.} =
  let url = WOLFRAM_URL & encodeUrl(input)
  echo url
  var client = newAsyncHttpClient()  
  var resp = await client.get(url)

  if resp.status.startsWith("200"):
    let d = q(parseHtml(newStringStream(resp.body)))
    let results = d.select("pod plaintext")    
    var answer = ""
    if results.len > 0:
      for r in results:      
        answer &= r.innerText() & "\n"
    else:
      answer = "Thật ngại quá đi 😜"
    sendMessage(chatId, answer)

proc findButts(chatId: BiggestInt) {.async.} =
  var client = newAsyncHttpClient()
  let resp = await client.get("http://api.obutts.ru/noise/1")

  if resp.status.startsWith("200"):
    let response = parseJson(resp.body)
    if len(response) > 0:
      let url = "http://media.obutts.ru/" & response[0]["preview"].str
      let tmp = mktemp() & ".jpg"
      downloadFile(url, tmp)
      echo url, " ", tmp
      var data = newMultipartData({"chat_id": $chatId})
      data.addFiles({"photo": tmp})

      echo postContent(SEND_PHOTO_URL, multipart=data)
      tmp.removeFile

proc findBoobs(chatId: BiggestInt) {.async.} =
  var client = newAsyncHttpClient()
  let resp = await client.get("http://api.oboobs.ru/noise/1")

  if resp.status.startsWith("200"):
    let response = parseJson(resp.body)
    if len(response) > 0:
      let url = "http://media.oboobs.ru/" & response[0]["preview"].str
      let tmp = mktemp() & ".jpg"
      downloadFile(url, tmp)
      echo url, " ", tmp
      var data = newMultipartData({"chat_id": $chatId})
      data.addFiles({"photo": tmp})

      echo postContent(SEND_PHOTO_URL, multipart=data)
      tmp.removeFile  
    
proc getUpdates() {.async.} =
  #while true:
  echo "update"
  try:
    let client = newAsyncHttpClient()
    var resp = await client.get(GET_UPDATE_URL & "?offset=" & $(lastUpdateId+1))
    echo resp.status, resp.body
    if resp.status[0..2] == "200":      
      let response = parseJson(resp.body)
      if response["ok"].bval:
        for update in response["result"]:
          echo update["update_id"], " ", lastUpdateId
          if update["update_id"].num > lastUpdateId:
            lastUpdateId = update["update_id"].num
            let message = update["message"]
            let chatId = message["chat"]["id"].num
            echo message
            if not message["text"].isNil:
              let query = message["text"].str
              if query.startsWith("!butts"):
                discard findButts(chatId)
              elif query.startsWith("!boobs"):
                discard findBoobs(chatId)
              elif query[0] == '!':
                discard search(chatId, query[1..query.len-1])
              else:
                discard
                
    client.close()
  except OverflowError:
    echo("overflow!")
  except ValueError:
    echo("could not convert string to integer")
  except IOError:
    echo("IO error!")
  except:
    echo "Unknown exception!"
  finally:
    discard getUpdates()
  

when isMainModule:
  
  asyncCheck getUpdates()
  runForever()
