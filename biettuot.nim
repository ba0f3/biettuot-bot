import asyncdispatch
import httpclient
import streams
import htmlparser
import xmltree
import json
import q
from cgi import encodeUrl

const
  SEND_MESSAGE_URL = "https://api.telegram.org/bot" & TELEGRAM_TOKEN &  "/sendMessage"
  GET_UPDATE_URL = "https://api.telegram.org/bot" & TELEGRAM_TOKEN &  "/getUpdates"
  
  WOLFRAM_URL = "http://api.wolframalpha.com/v2/query?appid=" & WOLFRAM_TOKEN & "&format=plaintext&input="
  
var
  lastUpdateId: BiggestInt = 0

proc sendMessage(chatId: BiggestInt, text: string) {.inline.} =
  var data = newMultipartData()
  data["chat_id"] = $chatId
  data["text"] = text
  
  echo postContent(SEND_MESSAGE_URL, multipart=data)

proc parseResult(chatId: BiggestInt, xml: string) =
  discard  

proc search(chatId: BiggestInt, input: string) {.async.} =
  let url = WOLFRAM_URL & encodeUrl(input)
  echo url
  var client = newAsyncHttpClient()  
  var resp = await client.get(url)

  echo resp.status
  if resp.status[0..2] == "200":
    let d = q(parseHtml(newStringStream(resp.body)))
    let results = d.select("pod plaintext")    
    var answer = ""
    if results.len > 0:
      for r in results:      
        answer &= r.innerText() & "\n"
    else:
      answer = "Thật ngại quá đi 😜"
    sendMessage(chatId, answer)
    
proc getUpdates(client: AsyncHttpClient) {.async.} =
  while true:
    var resp = await client.get(GET_UPDATE_URL & "?offset=" & $(lastUpdateId+1))
    if resp.status[0..2] != "200":
      continue
    let response = parseJson(resp.body)
    if response["ok"].bval:
      for update in response["result"]:
        echo update["update_id"], " ", lastUpdateId
        if update["update_id"].num > lastUpdateId:
          lastUpdateId = update["update_id"].num
        
          let message = update["message"]
          echo message
          if not message["text"].isNil:
            let query = message["text"].str
            if query[0] == '!':
              discard search(message["chat"]["id"].num, query[1..query.len-1])
  

when isMainModule:
  let client = newAsyncHttpClient()
  asyncCheck getUpdates(client)
  runForever()
