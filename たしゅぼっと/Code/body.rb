require 'discordrb'
require_relative 'commands_help.rb'
require_relative 'database.rb'
require_relative 'narou_api.rb'

@bot = Discordrb::Commands::CommandBot.new(token: ENV["TOKEN"], client_id: ENV["CLIENT_ID"], prefix:'?')
# Cache(Botクラスにインクルードされているモジュール)を使用してたしゅぼっとを指すUserクラスのインスタンスを作成する。
# @bot_user_object = @bot.user(784773848688099380)

def process_unless_self_introduction_channel(event_channel_id)
  if event_channel_id == 784702508927811604
    @bot.send_temporary_message(event_channel_id, "自己紹介チャンネルでは使えないコマンドです...", 3)
  else
    yield
  end
end

def admin_member?(member, server)
  # 管理者権限を持っているか判定するのにビットフラグを使用しているが、もしかしたら同挙動のメソッドがあるかもしれない。
  return true if member == server.owner
  user_has_role_list = member.roles << server.everyone_role
  user_has_admin_roles = user_has_role_list.select { |user_has_role| user_has_role.permissions.bits.to_s(2)[-4] == "1" }
  user_has_admin_roles.empty? ? false : true
end

# 自己紹介チャンネルにおいて、規定に沿っていないメッセージを自動削除する機能
# await!メソッドを使って常時待機させるので、他のコマンドを実行できるように、Threadを利用する。
Thread.new do
  message_list = []
  tashumi_server_id = 784700980381351936
  self_introduction_channel_id = 784702508927811604
  self_introduction_channel = @bot.channel(self_introduction_channel_id, tashumi_server_id)

  # Message(Object)が戻り値。messageメソッドを使用しない場合は、Discordrb::Events::MessageEventクラスのインスタンスが戻り値。
  Thread.new { loop { message_list << self_introduction_channel.await!.message } }

  # たしゅぼっとのメッセージに反応しないので、たしゅぼっと自体を待機するようにしたが、反応しない。
  # 改善策として、それぞれのコマンドの処理を process_unless_self_introduction_channel のブロックに書いている。
  # Thread.new { loop { message_list << @bot_user_object.await!.message } }

  loop do
    if message_list.empty?
      sleep 3
      next
    end

    messages_to_delete = message_list.reject { |message| /【ニックネーム】.+\n【ゲームタグ】.+\n【一言】.+/.match?(message.content) }
    message_list.clear
    next if messages_to_delete.empty?

    messages_to_delete_ids = messages_to_delete.map(&:id)
    mention_format_delete_to_message_authors = messages_to_delete.map { |delete_message| "<@#{delete_message.author.id}>"}.uniq

    # send_messageの戻り値は送信したメッセージのMessageオブジェクト。
    messages_to_delete_ids << self_introduction_channel.send_message("#{mention_format_delete_to_message_authors.join(" ")} 自己紹介以外のメッセージは禁止されています！").id

    sleep 5
    Discordrb::API::Channel.bulk_delete_messages(@bot.token, self_introduction_channel_id, messages_to_delete_ids)
    messages_to_delete.clear
    messages_to_delete_ids.clear
    mention_format_delete_to_message_authors.clear
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
    return "おめーに管理者権限、ねぇから！" unless admin_member?(event.user, event.server)

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
    requesting_user = event.author
    requesting_user_id = requesting_user.id
    check_parameter_message = event_channel.send_message("**個数(1~5)**と**指定したいジャンルすべて**を順番にスペース区切りで入力してください。\nジャンルが指定されなかった場合は、以下のジャンルすべてが適用されます。\n\n※20秒経ったら処理は止まります。0と発言すると強制的に処理は止まります。```恋愛\nハイファンタジー\nローファンタジー```")

    message_specified_parameter_event = requesting_user.await!(timeout: 20)
    if message_specified_parameter_event.nil?
      check_parameter_message.edit("20秒が経過しました。処理を停止します。")
      return
    end

    begin
      # 指定作品数をspecified_novels_numberに、指定ジャンルをspecified_genresに代入する。
      specified_parameter_list = message_specified_parameter_event.message.content.split
      specified_novels_number = Integer(specified_parameter_list.shift)
      specified_genres = specified_parameter_list
    rescue ArgumentError, TypeError
      return "入力形式が違うよ。helpコマンドで確認してね。"
    end

    if specified_novels_number == 0
      check_parameter_message.edit("処理を停止しました！")
      return
    end

    unless (1..5).include?(specified_novels_number)
      check_parameter_message.edit("<@#{requesting_user_id}> 指定できる作品数は1~5個だよ。")
      return
    end

    if specified_genres.size > 3
      check_parameter_message.edit("<@#{requesting_user_id}> 指定ジャンルが多すぎます！")
      return
    end

    wrong_genre_list = []
    narou_api_format_specified_genres = ""
    specified_genres.map do |genre|
      case genre
      when "恋愛" then narou_api_format_specified_genres << "101-102"
      when "ハイファンタジー" then narou_api_format_specified_genres << "201"
      when "ローファンタジー" then narou_api_format_specified_genres << "202"
      else
        wrong_genre_list << "「#{genre}」"
      end
    end

    unless wrong_genre_list.empty?
      check_parameter_message.edit("<@#{requesting_user_id}> 存在しないジャンル#{wrong_genre_list.join(",")}が指定されています！")
      return
    end

    check_parameter_message.edit("リクエスト中です...\nこの処理には時間がかかります。少々お待ち下さい。")

    sleep 3
    novels_data = get_narou_novel(specified_novels_number, narou_api_format_specified_genres)

    embed = Discordrb::Webhooks::Embed.new
    embed.title = "おすすめの作品"
    embed.description = "日間ポイントの高い順100件の中から無作為に選んでいます。"
    novels_data.each { |novel_data| embed.add_field(name: "#{novel_data["title"]}", value: "ncode: #{novel_data["ncode"]} genre: #{novel_data["genre"]}", inline: false) }
    check_parameter_message.edit("", embed)
  end
end

@bot.run
