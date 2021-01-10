require "net/http"
require "zlib"
require "json"
require "uri"

@response_by_genre = {}
all_genre_combination = ["201", "202", "101-102", "201-202", "101-102-201", "101-102-202", "101-102-201-202"]
all_genre_combination.each do |genres|
  parameters_setting = {
    of: "t-n-g",
    lim: 100,
    order: "dailypoint",
    genre: genres
  }
  narou_api_format_parameter = ''
  parameters_setting.each { |key, value| narou_api_format_parameter << "&#{key}=#{value}" }

  uri = URI.parse("https://api.syosetu.com/novelapi/api/?gzip=5&out=json#{narou_api_format_parameter}")
  deflated_response = Net::HTTP.get(uri)

  # 16を指定することで、gzip形式のみのデコードにする。
  # これにより、incorrect header check (Zlib::DataError)が発生しなくなる。
  inflate_stream = Zlib::Inflate.new(16)
  inflated_json_response = inflate_stream.inflate(deflated_response)
  response = JSON.parse(inflated_json_response)
  response.shift # allcountの削除

  @response_by_genre[genres] = response
  sleep 1
end

def get_narou_novel(number, specified_genres)
  response = @response_by_genre[specified_genres]
  response.sample(number)
end
