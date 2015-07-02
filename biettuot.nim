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
import parsecfg
import streams
import telebot

var
  TELEGRAM_TOKEN: string
  WOLFRAM_TOKEN: string
  WOLFRAM_URL = "http://api.wolframalpha.com/v2/query?appid=$#&format=plaintext&input=$#"
  
proc loadConfig(path: string) =
  let f = newFileStream(path, fmRead)
  if f.isNil:
    echo "Cannot open: " & path
    quit(1)
  else:
    var p: CfgParser
    p.open(f, path)
    while true:
      let e = p.next()
      case e.kind
      of cfgEof:
        break
      of cfgKeyValuePair:
        if e.key == "telegramToken":
          TELEGRAM_TOKEN = e.value
        elif e.key == "wolframToken":
          WOLFRAM_TOKEN = e.value
      else:
        discard
    p.close()

if "biettuot.local.cfg".fileExists:
  loadConfig("biettuot.local.cfg")
else:
  loadConfig("biettuot.cfg")

  
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

  
proc search(b: TeleBot, chatId: int, input: string) {.async.} =
  let url = WOLFRAM_URL % [WOLFRAM_TOKEN, encodeUrl(input)]
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
    discard await b.sendMessage(chatId, answer)

proc findButts(b: TeleBot, chatId: int) {.async.} =
  var client = newAsyncHttpClient()
  let resp = await client.get("http://api.obutts.ru/noise/1")

  if resp.status.startsWith("200"):
    let response = parseJson(resp.body)
    if len(response) > 0:
      let url = "http://media.obutts.ru/" & response[0]["preview"].str
      let tmp = mktemp() & ".jpg"
      downloadFile(url, tmp)
      echo url, " ", tmp
      discard await b.sendPhoto(chatId, tmp)
      tmp.removeFile

proc findBoobs(b: TeleBot, chatId: int) {.async.} =
  var client = newAsyncHttpClient()
  let resp = await client.get("http://api.oboobs.ru/noise/1")

  if resp.status.startsWith("200"):
    let response = parseJson(resp.body)
    if len(response) > 0:
      let url = "http://media.oboobs.ru/" & response[0]["preview"].str
      let tmp = mktemp() & ".jpg"
      downloadFile(url, tmp)
      echo url, " ", tmp
      discard await b.sendPhoto(chatId, tmp)
      tmp.removeFile  
    
proc main() {.async.} =
  var bot = newTeleBot(TELEGRAM_TOKEN)
  var updates: seq[Update]
  while true:
    updates = await bot.getUpdates()

    for update in updates:
      if update.message.kind == kText:
        let query = update.message.text
        let chatId = update.message.chat.id()
        if query.startsWith("!butts"):
          discard bot.sendChatAction(chatId, "upload_photo")
          discard bot.findButts(chatId)
        elif query.startsWith("!boobs"):
          discard bot.sendChatAction(chatId, "upload_photo")
          discard bot.findBoobs(chatId)
        elif query[0] == '!':
          discard bot.sendChatAction(chatId, "typing")          
          discard bot.search(chatId, query[1..query.len-1])
        else:
          discard

asyncCheck main()
runForever()
