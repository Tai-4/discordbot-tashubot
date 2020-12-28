require "net/http"
require "zlib"
require "json"
require "uri"

def get_narou_novel(number, requested_genre)
  parameter_settings = {
    of: "t-n-g",
    lim: 100,
    order: "dailypoint",
    genre: requested_genre
  }

  parameter = ""
  parameter_settings.each do |key, value|
    parameter << "&#{key}=#{value}"
  end

  uri = URI.parse("https://api.syosetu.com/novelapi/api/?gzip=5&out=json#{parameter}")
  deflated_response = Net::HTTP.get(uri)

  # 16を指定することで、gzip形式のみのデコードにする。これにより、incorrect header check (Zlib::DataError)が発生しなくなる。
  inflate_stream = Zlib::Inflate.new(16)
  inflated_json_response = inflate_stream.inflate(deflated_response)

  response = JSON.parse(inflated_json_response)
  response.shift # allcountの削除
  response.sample(number)
end
