# coding:utf-8
require 'sinatra/base'
require 'yaml'
require 'haml'

class HotCola < Sinatra::Base
  configure do
    Setting = OpenStruct.new(
                             :title => 'HOT-COLA',
                             :member_data => './config/members.yaml',
                             :log_file => './log/chat_log.txt',
                             :log_max_num => 50 # 保存するチャットログの行数
                             )

    raise "ERROR: No members file error!" unless File.exist?( Setting.member_data )

    Members = YAML.load_file( Setting.member_data )
    raise "ERROR: There is no member!" if Members.empty?
  end

  def write_chat_log( chat_log )
    open( Setting.log_file, 'w' ) do |f|
      f.puts chat_log.to_yaml
    end
  end

  def read_chat_log
    # ログファイルがなければ作る
    unless File.exist?( Setting.log_file )
      write_chat_log( [] )
    end
    return YAML.load_file( Setting.log_file )
  end

  def notify( warn_message, message )
    # --hint=int:transient:1 は連打されたときにいちいちポップアップをクリックしないで済むように
    system "notify-send --hint=int:transient:1 -t 1000 #{Regexp.escape(warn_message)} #{Regexp.escape(message)}"
  end

  # メンバーならブロックの実行結果を返す
  def if_member( ip )
    if Members[ ip ]
      return yield
    else
      warn "#{Time.now} : Unknown user!"
      return "Error !"
    end
  end

  get '/style.css' do
    sass :style
  end

  get '/' do
    if_member( request.ip ) do
      @title = Setting.title
      haml :index
    end
  end

  get '/chat' do
    @chat_log = read_chat_log
    haml :chat
  end

  # 呼び出しボタンが押されたら
  post '/call' do
    if_member( request.ip ) do
      requester = Members[ request.ip ]
      requester = 'Unknown' unless requester

      warn "#{Time.now} : Ring! Ring! from #{requester}"

      notify( "Ring!", requester )
    end
  end

  # 簡易チャット機能
  post '/chat' do
    if_member( request.ip ) do
      @chat_log = read_chat_log

      chat_data = {
        post_time: Time.now.strftime('%m/%d %H:%M'),
        member:    Members[ request.ip ],
        text:      params['content']
      }
      notify( chat_data[:member], chat_data[:text] )
      warn chat_data

      @chat_log.unshift chat_data
      write_chat_log( @chat_log[0..(Setting.log_max_num-1)] )
      haml :chat
    end
  end
end

HotCola.run!:host => 'localhost', :port => 4567
