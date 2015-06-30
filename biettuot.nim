import httpclient
import streams
import htmlparser
import xmltree
import json
import q
from cgi import encodeUrl

const
  TELEGRAM_TOKEN = "XYZ:ABCD"
  WOLFRAM_TOKEN = "XXX"

  botEndpoint = "https://api.telegram.org/bot" & TELEGRAM_TOKEN &  "/"
  wolframEndpoint = "http://api.wolframalpha.com/v2/query?appid=" & WOLFRAM_TOKEN & "&format=plaintext&input="

var
  lastUpdateId: BiggestInt = 653377437

proc sendMessage(chatId: BiggestInt, text: string) =
  var data = newMultipartData()
  data["chat_id"] = $chatId
  data["text"] = text
  
  echo postContent(botEndpoint & "sendMessage", multipart=data)

proc search(chatId: BiggestInt, input: string) =
  let url = wolframEndpoint & encodeUrl(input)
  echo url
  let xml = getContent(url)
  let d = q(parseHtml(newStringStream(xml)))
  let results = d.select("pod plaintext")

  var answer = ""
  if results.len > 0:
    for r in results:      
      answer &= r.innerText() & "\n"
  else:
    answer = "Thật ngại quá đi 😜"
  sendMessage(chatId, answer)      
    
  
proc getUpdates() =
  var data = newMultipartData()
  data["offset"] = $(lastUpdateId+1)
  let json = postContent(botEndpoint & "getUpdates", multipart=data)
  
  let response = parseJson(json)
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
          search(message["chat"]["id"].num, query[1..query.len-1])

when isMainModule:
  #runForever()
  while true:
    getUpdates()
