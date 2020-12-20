require "pg"

$connection = PG::connect(
  host: ENV["HOST"],
  user: ENV["DBUSER"],
  password: ENV["PASSWORD"],
  dbname: ENV["DBNAME"]
)

def get_music_list(user_id)
  result = []
  $connection.exec("SELECT music_name FROM added_music WHERE user_id = '#{user_id}'") do |pg_results|
    pg_results.each { |pg_result| result << pg_result["music_name"]}
  end
  result
end

def add_music(music_title, id_user_requesting)
  return "「#{music_title}」は既に追加されています..." if get_music_list(id_user_requesting).include?(music_title)

  $connection.exec("INSERT INTO added_music VALUES ('#{music_title}', '#{id_user_requesting}')")
  "「#{music_title}」の追加が完了しました！"
end

def choose_music(song_count, id_user_requesting)
  music_list = get_music_list(id_user_requesting)
  if song_count == 0 || song_count > music_list.size
    "現在指定できる曲数は、1~#{music_list.size}個です。"
  else
    music_list.sample(song_count).join("\n\n")
  end
end
