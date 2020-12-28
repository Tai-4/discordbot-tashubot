require 'discordrb'
require_relative 'commands_help.rb'
require_relative 'database.rb'
require_relative 'narou_api.rb'

@bot = Discordrb::Commands::CommandBot.new(token: ENV["TOKEN"], client_id: ENV["CLIENT_ID"], prefix:'?')
# @bot_user_object = @bot.user(784773848688099380) # Cache(モジュール)を使用してたしゅぼっとを指すUserクラスのインスタンスを作成。

def process_unless_self_introduction_channel(event_channel_id)
  if event_channel_id == 784702508927811604
    @bot.send_temporary_message(event_channel_id, "自己紹介チャンネルでは使えないコマンドです...", 3)
  else
    yield
  end
end

# 自己紹介チャンネルにおいて、規定に沿っていないメッセージを自動削除する
# await!メソッドで永遠に待機させる必要があるので、マルチスレッド機能を利用する。
Thread.new do
  message_list = []
  self_introduction_channel_id = 784702508927811604
  self_introduction_channel = @bot.channel(self_introduction_channel_id, 784700980381351936) # Cache(モジュール)を使用して自己紹介チャンネルのオブジェクトを生成。[引数: (チャンネルID, サーバーID) ]

  Thread.new { loop { message_list << self_introduction_channel.await!.message } } # Message(Object)が戻り値。messageメソッドを使用しない場合は、Discordrb::Events::MessageEventというクラスのインスタンスが返される。
  # Thread.new { loop { message_list << @bot_user_object.await!.message } }          # たしゅぼっとのメッセージに反応しないので、たしゅぼっと自体を待機するようにしたが、失敗。

  loop do
    if message_list.empty?
      sleep 3
      next
    end

    delete_messages = message_list.reject { |message| /【ニックネーム】.*\n【ゲームタグ】.*\n【一言】.*/.match?(message.content) }
    message_list.shift(delete_messages.size)
    next if delete_messages.empty?

    delete_messages_ids = delete_messages.map(&:id)
    delete_messages_authors_mention = delete_messages.map { |delete_message| "<@#{delete_message.author.id}>"}.uniq
    # send_messageの戻り値は送信したメッセージのMessage(Object)なので、idメソッドを呼び出せる。
    delete_messages_ids << self_introduction_channel.send_message("#{delete_messages_authors_mention.join(" ")} 自己紹介以外のメッセージは禁止されています！").id

    sleep 5
    Discordrb::API::Channel.bulk_delete_messages(@bot.token, self_introduction_channel_id, delete_messages_ids)
    delete_messages.clear
    delete_messages_ids.clear
    delete_messages_authors_mention.clear
  end
end

# 実験: 別ファイルに処理を記述して、実行させることは可能だろうか。 => 可能
@bot.command :help do |event|
  process_unless_self_introduction_channel(event.channel.id) do
    command_name = event.message.content.split[1]
    commands_help(event.channel, command_name)
  end
end

# command定義においては、ブロックの戻り値がコマンドが送信されたチャンネルに送信されることを利用することでコマンドが送信されたチャンネルにメッセージを送信することを実現している箇所もあります。
@bot.command :cmsg do |event|
  process_unless_self_introduction_channel(event.channel.id) do
    begin
      target_message_id = event.message.content.split[1]
      target_message_id ? Discordrb::API::Channel.message(@bot.token, event.channel.id, target_message_id) : "入力形式が違うよ。helpコマンドで確認してね。"
    rescue RestClient::NotFound => e
      "指定したメッセージは見つからなかったよ。"
    end
  end
end

@bot.command :name do |event|
  process_unless_self_introduction_channel do
    name = event.author.username         # event.user.name も可(エイリアス)
    nickname = event.author.nickname     # event.user.nick も可(エイリアス)
    %(```Your username: #{name}\nYour nickname: #{nickname ? "#{nickname}": "None" }```)
  end
end

@bot.command :addm do |event|
  process_unless_self_introduction_channel(event.channel.id) do
    id_user_requesting = event.author.id
    music_title = event.message.content.split[1]
    return "曲名は必ず指定 ＼_(・ω・`)ココ重要！" unless music_title
    add_music(music_title, id_user_requesting)
  end
end

@bot.command :chom do |event|
  process_unless_self_introduction_channel(event.channel.id) do
    begin
      id_user_requesting = event.author.id
      song_count = Integer(event.message.content.split[1])
    rescue ArgumentError, TypeError
      return "入力形式が違うよ。helpコマンドで確認してね。"
    end

    choose_music(song_count, id_user_requesting)
  end
end

@bot.command :dem do |event|
  process_unless_self_introduction_channel(event.channel.id) do
    unless event.author.roles[0].permissions.bits.to_s(2)[-4] == "1" # 役職に管理者があるか確認(ビットフラグ)
      return "おめーに管理者権限、ねぇから！"
    end

    begin
      number = Integer(event.message.content.split[1])
    rescue ArgumentError, TypeError
      return "入力形式が違うよ。helpコマンドで確認してね。"
    end

    if (1..100).include?(number)
      event_channel_id = event.channel.id
      event_message_id = event.message.id
      message_data = Discordrb::API::Channel.messages(@bot.token, event_channel_id, number, event_message_id)
      message_ids = JSON.parse(message_data).map { |data| data["id"]}

      if message_ids.size == 100
        Discordrb::API::Channel.delete_message(@bot.token, event_channel_id, event_message_id)
        Discordrb::API::Channel.bulk_delete_messages(@bot.token, event_channel_id, message_ids)
      else
        message_ids << event_message_id
        Discordrb::API::Channel.bulk_delete_messages(@bot.token, event_channel_id, message_ids)
      end
    else
      "指定できる個数は1~100個です。"
    end
  end
end

@bot.command :narou do |event|
  event_channel = event.channel
  event_channel_id = event_channel.id
  process_unless_self_introduction_channel(event_channel_id) do
    user_requesting = event.author
    check_parameter_message_id = event_channel.send_message("**個数(1~5)**と**指定したいジャンルすべて**を順番にスペース区切りで入力してください。\nジャンルが指定されなかった場合は、以下のジャンルすべてが適用されます。```恋愛\nハイファンタジー\nローファンタジー```").id

    begin
      message_content = user_requesting.await!.message.content.split
      number = Integer(message_content.shift) # 最初の要素を削除しつつ取得する。
      return "指定できる作品数は1~5個だよ。" unless (1..5).include?(number)
    rescue ArgumentError, TypeError
      return "入力形式が違うよ。helpコマンドで確認してね。"
    end

    genre = ""
    message_content.map do |targeted_genre|
      case targeted_genre
      when "恋愛" then genre << "101-102"
      when "ハイファンタジー" then genre << "201"
      when "ローファンタジー" then genre << "202"
      else
        event_channel.send_temporary_message("存在しないジャンルが指定されています！\n備考:「#{targeted_genre}」", 3)
      end
    end
    genre = "101-102-201-202" if genre.empty?

    sleep 3
    novels_data = get_narou_novel(number, genre)
    event_channel.send_embed do |embed|
      embed.title = "おすすめの作品"
      embed.description = "日間ポイントの高い順100件の中から無作為に選んでいます。"
      novels_data.each { |novel_data| embed.add_field(name: "#{novel_data["title"]}", value: "ncode: #{novel_data["ncode"]} genre: #{novel_data["genre"]}", inline: false) }
    end

    Discordrb::API::Channel.delete_message(@bot.token, event_channel_id, check_parameter_message_id)
  end
end

@bot.run
