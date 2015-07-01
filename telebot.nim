import asyncdispatch
import httpclient
import json
import strutils

const
  API_URL = "https://api.telegram.org/bot$#/$#"


type
  TeleBot* = ref object of RootObj
    token: string
    lastUpdateId: BiggestInt

  ChatKind* = enum
    kUser
    kGroupChat

  User* = ref object of RootObj
    id*: int
    firstName*: string
    lastName*: string
    username*: string

  GroupChat* = ref object of RootObj
    id*: int
    title*: string

  Chat* = ref object of RootObj
    case kind*: ChatKind
    of kUser:
      user*: User
    of kGroupChat:
      group*: GroupChat

  PhotoSize* = ref object of RootObj
    fileId*: string
    width*: int
    height*: int
    fileSize*: int
      
  Audio* = ref object of RootObj
    fileId*: string
    duration*: int
    mimeType*: string
    fileSize*: int

  Document* = ref object of RootObj
    fileId*: string
    thumb*: PhotoSize
    fileName*: string
    mimeType*: string
    fileSize*: int

  Sticker* = ref object of RootObj
    fileId*: string
    width*: int
    height*: int
    thumb*: PhotoSize
    fileSize*: int
    
  Video* = ref object of RootObj
    fileId*: string  
    width*: int
    height*: int
    duration*: int
    thumb*: PhotoSize
    mimeType*: string
    fileSize*: int
    caption*: string
    
  Contact* = ref object of RootObj
    phoneNumber*: string
    firstName*: string
    lastName*: string
    userId*: string

  Location* = ref object of RootObj
    longitude*: float
    latitude*: float

  UserProfilePhotos* = ref object of RootObj
    totalCount*: int
    photos*: seq[seq[PhotoSize]]

  KeyboardKind* = enum
    ReplyKeyboardHide
    ReplyKeyboardMarkup
    ForceReply

  KeyboardMarkup* = ref object of RootObj
    selective*: bool
    case kind*: KeyboardKind
    of ReplyKeyboardMarkup:
      keyboard*: seq[seq[string]]
      resizeKeyboard*: bool
      oneTimeKeyboard*: bool
    of ReplyKeyboardHide:
      hideKeyboard*: bool
    of ForceReply:
      forceReply*: bool
        
  MessageKind* = enum
    kText
    kAudio
    kDocument
    kPhoto
    kSticker
    kVideo
    kContact
    kLocation
    kNewChatParticipant
    kLeftChatParticipant
    kNewChatTitle
    kNewChatPhoto
    kDeleteChatPhoto
    kGroupChatCreated
          

  Message* = ref object of RootObj
    messageId*: int
    fromUser*: User
    date*: int
    chat*: Chat
    forwardFrom*: User
    forwardDate*: int
    replyToMessage*: Message
    case kind: MessageKind
    of kText:
      text*: string
    of kAudio:
      audio*: Audio
    of kDocument:
      document*: Document
    of kPhoto:
      photo*: seq[PhotoSize]
    of kSticker:
      sticker*: Sticker
    of kVideo:
      video*: Video
    of kContact:
      contact*: Contact
    of kLocation:
      location*: Location
    of kNewChatParticipant:
      newChatParticipant*: User
    of kLeftChatParticipant:
      leftChatParticipant*: User
    of kNewChatTitle:
      newChatTitle*: string
    of kNewChatPhoto:
      newChatPhoto: seq[PhotoSize]
    of kDeleteChatPhoto:
      deleteChatPhoto: bool
    of kGroupChatCreated:
      groupChatCreated: bool

proc `$`*(k: KeyboardMarkup): string =
  var j = newJObject()
  j["selective"] = %k.selective
  case k.kind  
  of ReplyKeyboardMarkup:
    var keyboard: seq[string] = @[]
    var kb = newJArray()
    for x in k.keyboard:
      var n = newJArray()
      for y in x:
        n.add(%y)
      kb.add(n)
        
    j["keyboard"] = kb
    j["resize_keyboard"] = %k.resizeKeyboard
    j["one_time_keyboard"] = %k.oneTimeKeyboard
  of ReplyKeyboardHide:
    j["hide_keyboard"] = %k.hideKeyboard
  of ForceReply:
    j["force_reply"] = %k.forceReply  
  result = $j

proc newReplyKeyboardMarkup*(kb: seq[seq[string]], rk = false, otk = false, s = false): KeyboardMarkup =
  new(result)
  result.kind = ReplyKeyboardMarkup
  result.keyboard = kb
  result.resizeKeyboard = rk
  result.oneTimeKeyboard = otk
  result.selective = s

proc newReplyKeyboardHide*(hide = true, s = false): KeyboardMarkup =
  new(result)
  result.kind = ReplyKeyboardHide
  result.hideKeyboard = hide
  result.selective = s

proc newForceReply*(f = true, s = false): KeyboardMarkup =
  new(result)
  result.kind = ForceReply
  result.forceReply = f
  result.selective = s
  
proc parseUser(n: JsonNode): User =
  new(result)      
  result.id = n["id"].num.int
  result.firstName = n["first_name"].str
  if not n["last_name"].isNil:
    result.lastName = n["last_name"].str
  if not n["username"].isNil:
    result.username = n["username"].str  
      
proc newTeleBot*(token: string): TeleBot =
  new(result)
  result.token = token
  result.lastUpdateId = 0

proc getMe*(b: TeleBot): Future[User] {.async.} =
  let endpoint  = API_URL % [b.token, "getMe"]
  echo endpoint
  let client = newAsyncHttpClient()

  let r = await client.get(endpoint)
  if r.status.startsWith("200"):
    
    var obj = parseJson(r.body)
    if obj["ok"].bval == true:
      result = parseUser(obj["result"])      
  else:
    raise newException(IOError, r.status)
    
  client.close()

proc sendMessage*(b: TeleBot, chatId: int, text: string, disableWebPagePreview = false, replyToMessageId = 0, replyMarkup: KeyboardMarkup = nil): Future[Message] {.async.} =
  let endpoint = API_URL % [b.token, "sendMessage"]
  echo endpoint

  var data = newMultipartData()
  
  data["chat_id"] = $chatId
  data["text"] = text
  if disableWebPagePreview:
    data["disable_web_page_preview"] = "true"
  if replyToMessageId != 0:
    data["reply_to_message_id"] = $replyToMessageId
  if not replyMarkup.isNil:
    data["reply_markup"] = $replyMarkup

  let client = newAsyncHttpClient()
  let r = await client.post(endpoint, multipart=data)
  if r.status.startsWith("200"):
    var obj = parseJson(r.body)
    if obj["ok"].bval == true:
      echo r.body
  else:
    raise newException(IOError, r.status)

  client.close()
  
  
  
  
  
#proc sendMessage(telebot: TeleBot, 
