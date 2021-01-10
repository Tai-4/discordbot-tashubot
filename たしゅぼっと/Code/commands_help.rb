require 'discordrb'

File.open("#{__dir__.encode("UTF-8")}/body.rb", "r") do |file|
  file_data = file.readlines
  @commands_list = file_data.map { |datum| datum.match(/@bot.command :(.+) do |.+|/)[1] }.compact!
  @commands_list_for_embed = @commands_list.map { |command| "`#{command}`"}.join(", ")
end

def send_help_embed(channel_object, title = nil, attribute = nil, command_format_description = nil)
  channel_object.send_embed do |embed|
    embed.title = "コマンド名: #{title}"
    embed.description = "種類: #{attribute[0]}\n説明:\n```#{attribute[1]}```"
    embed.add_field(name: "入力形式", value: command_format_description, inline: false) if command_format_description # Discordrb::Webhooks::EmbedField.new でも可(このときは embed.push() になる。)
  end
end

def send_commands_list(channel_object)
  channel_object.send_embed do |embed|
    embed.title = "Help"
    embed.description = "たしゅぼっとで使えるコマンド一覧です。"
    embed.add_field(name: "Commands", value: "#{@commands_list_for_embed}", inline: false)
    embed.footer = Discordrb::Webhooks::EmbedFooter.new(text: "[?help コマンド名]で詳細を開けるよ")
  end
end

def send_help(event_channel_object, command_name)
  if command_name.nil?
    send_commands_list(event_channel_object)
    return
  end

  unless @commands_list.include?(command_name)
    event_channel_object.send_message("#{command_name}というコマンドは存在しないよ！")
    return
  end

  case command_name
  when "help"
    send_help_embed(
      event_channel_object, "help", ["一般コマンド", "コマンド一覧を表示します。属性にコマンド名を指定すると、そのコマンドの詳細を確認できます。"], "[?help コマンド名]"
    )
  when "cmsg"
    send_help_embed(
      event_channel_object, "cmsg", ["一般コマンド", "属性にメッセージIDを指定すると、そのメッセージの内容を表示します。属性指定は必須です。"], "[?cmsg メッセージID]"
    )
  when "name"
    send_help_embed(
      event_channel_object, "name", ["一般コマンド", "discord上のユーザー名とこの鯖でのニックネームを表示します。"], "[?name]"
    )
  when "addm"
    send_help_embed(
      event_channel_object, "addm", ["一般コマンド", "?chomで提示される曲を追加できます。属性指定は必須です。"], "[?addm 曲名]"
    )
  when "chom"
    send_help_embed(
      event_channel_object, "chom", ["一般コマンド", "?addで追加された曲の中から曲を提示します。属性指定は必須です。"], "[?name 曲数]"
    )
  when "dem"
    send_help_embed(
      event_channel_object, "dem", ["管理者コマンド", "属性に削除したいメッセージの数を指定すると、コマンドより前にあるメッセージをその数だけ削除し、同時にコマンドも削除します。)"], "[?dem メッセージ数]"
    )
  else
    send_help_embed(
      event_channel_object, command_name, ["？？？", "ヘルプがまだ用意されていないコマンドです。"]
    )
  end
  nil
end
