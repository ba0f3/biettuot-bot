import asyncdispatch
import httpclient
import streams
import htmlparser
import xmltree
import json
import q
from cgi import encodeUrl
import strutils
import os
import parsecfg
import streams
import telebot

var
  TELEGRAM_TOKEN: string
  WOLFRAM_TOKEN: string

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
      else:
        discard
    p.close()

if "biettuot.local.cfg".fileExists:
  loadConfig("biettuot.local.cfg")
else:
  loadConfig("biettuot.cfg")

proc buttHandler(b: Telebot, c: Command) {.async.} =
  var client = newAsyncHttpClient()
  let resp = await client.get("http://api.obutts.ru/noise/1")

  if resp.status.startsWith("200"):
    let response = parseJson(await resp.body)
    if len(response) > 0:
      let url = "http://media.obutts.ru/" & response[0]["preview"].str
      var message = newPhoto(c.message.chat.id, url)
      discard await b.send(message)

proc boobHandler(b: Telebot, c: Command) {.async.} =
  var client = newAsyncHttpClient()
  let resp = await client.get("http://api.oboobs.ru/noise/1")

  if resp.status.startsWith("200"):
    let response = parseJson(await resp.body)
    if len(response) > 0:
      let url = "http://media.oboobs.ru/" & response[0]["preview"].str
      var message = newPhoto(c.message.chat.id, url)
      discard await b.send(message)

let bot = newTeleBot(TELEGRAM_TOKEN)
bot.onCommand("butts", buttHandler)
bot.onCommand("boobs", boobHandler)
bot.poll(timeout=300)