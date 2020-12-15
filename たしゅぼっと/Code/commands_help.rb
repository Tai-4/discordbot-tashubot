require 'discordrb'

@bot = Discordrb::Commands::CommandBot.new(token: ENV["TOKEN"], client_id: ENV["CLINET_ID"], prefix:'?')

File.open('/app/たしゅぼっと/Code/body.rb', "r") do |file|
  file_data = file.readlines
  @commands_list = file_data.map { |datum| datum.match(/@bot.command :(.+) do |.+|/)[1] }.compact!
  @commands_list_for_help = @commands_list.map { |command| "`#{command}`"}.join(", ")
end

def create_help_embed(channel_object, title = nil, attribute = nil, input_format_description = nil)
  channel_object.send_embed do |embed|
    embed.title = "コマンド名: #{title}"
    embed.description = "種類: #{attribute[0]}\n説明:\n```#{attribute[1]}```"
    embed.add_field(name: "入力形式", value: input_format_description, inline: false) if input_format_description # Discordrb::Webhooks::EmbedField.new でも可(このときは embed.push() になる。)
  end
end

def commands_help(event_channel_object, command_name)
  if command_name.nil?
    return event_channel_object.send_embed do |embed|
      embed.title = "Help"
      embed.description = "たしゅぼっとで使えるコマンド一覧です。"
      embed.add_field(name: "Commands", value: "#{@commands_list_for_help}", inline: false)
      embed.footer = Discordrb::Webhooks::EmbedFooter.new(text: "[?help コマンド名]で詳細を開けるよ")
    end
  end

  if @commands_list.include?(command_name)
    case command_name
    when "help"
      create_help_embed(
        event_channel_object, "help", ["一般コマンド", "コマンド一覧を表示します。属性にコマンド名を指定すると、そのコマンドの詳細を確認できます。"], "[?help コマンド名]"
     )
    when "cmsg"
      create_help_embed(
        event_channel_object, "cmsg", ["一般コマンド", "属性にメッセージIDを指定すると、そのメッセージの内容を表示します。属性指定は必須です。"], "[?cmsg メッセージID]"
      )
    when "name"
      create_help_embed(
        event_channel_object, "name", ["一般コマンド", "discord上のユーザー名とこの鯖でのニックネームを表示します。"], "[?name]"
      )
    when "addm"
      create_help_embed(
        event_channel_object, "addm", ["一般コマンド", "?chomで提示される曲を追加できます。属性指定は必須です。"], "[?addm 曲名]"
      )
    when "chom"
      create_help_embed(
        event_channel_object, "chom", ["一般コマンド", "属性に曲数を指定すると、任意の曲を曲数だけ提示します。許可設定では、ユーザーによって追加された曲が選択されるかを変更可能です。曲数指定は必須です。許可設定はデフォルトでoffになっています。"], "[?name 曲数 (on/off)]"
      )
    when "dem"
      create_help_embed(
        event_channel_object, "dem", ["管理者コマンド", "属性に削除したいメッセージの数を指定すると、コマンドより前にあるメッセージをその数だけ削除します。(コマンド自体は数に含まれませんが、削除されます。)"], "[?dem メッセージ数]"
      )
    else
      create_help_embed(
        event_channel_object, command_name, ["？？？", "未実装または開発者用のコマンドだよ。"]
      )

    end
  else
    "#{command_name}というコマンドは存在しないよ！"
  end
end
