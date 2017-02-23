require 'sinatra'
require 'rubygems'
require 'tilt/erb'
require 'bcrypt'
require 'pony'
require 'bcrypt'
require_relative "grandbash_functions.rb"



get '/' do
    @title = 'Grandbash 2017'
    prizes = db.exec("select * from prizes order by draw_time desc")
    erb :winning_numbers, :locals => {:prizes => prizes, :message => "Search to see if you've won"}
end

get '/index.erb' do
  erb :index
end

get '/about' do
    @title = 'GrandBash| About WVU Childrens'
    erb :about
end

get '/rules' do
    @title = 'GrandBash| Rules'
    erb :rules
end


get '/faq' do
    @title = 'GrandBash| FAQ'
    erb :faq
end


get '/photos' do
    @title = 'GrandBash| Photos'
    erb :photos
end

get '/winning_numbers' do
    @title = 'GrandBash| Winning Numbers'
    prizes = db.exec("select * from prizes order by draw_time desc")
    erb :winning_numbers, :locals => {:prizes => prizes, :message => "Search to see if you've won"}
end


post '/winning_number_search' do
    number_searched = params[:search]
    prize = db.exec("SELECT name, img_location, description, draw_time, winning_number FROM prizes WHERE winning_number='#{number_searched}'") 
    winners = db.exec("SELECT winning_number FROM prizes where winning_number is not null")
    winning_numbers = extract_winning_numbers(winners)
    tickets_off_by_one = find_no_cigar(number_searched, winning_numbers)

   
    if winning_ticket?(prize)
      winning_message = "Congratulations, you have won!" 
      erb :winning_numbers,:locals =>{:prizes => prize, :message => winning_message}
    elsif tickets_off_by_one.count > 0
      string_tickets_off_by_one = convert_array_tickets_to_string(tickets_off_by_one) 
      missed_prize = db.exec("SELECT name, img_location, description, draw_time, winning_number FROM prizes WHERE winning_number in (#{string_tickets_off_by_one})") 
      winning_message = "You just missed by one digit!"
      erb :winning_numbers,:locals =>{:prizes => missed_prize, :message => winning_message}
    else
      winning_message = "Sorry, you haven't won anything yet."
      erb :winning_numbers,:locals =>{:prizes => missed_prize, :message => winning_message}
    end  
     
end
 

get '/contact' do
    @title = 'GrandBash| Contact Us'
    erb :contact
end



post '/contact-form' do
  name = params[:name]
  from = params[:email]
  to = "#{from}"                   
  comments = params[:message]
  subject= params[:subject]

    Pony.mail(
        :to => to, 
        :from => ENV['from_email'],
        :subject => "GrandBash", 
        :content_type => 'text/html', 
        :body => erb(:email2,:layout=>false),
        :via => :smtp, 
        :via_options => {
          :address              => 'smtp.gmail.com',
          :port                 => '587',
          :enable_starttls_auto => true,
          :user_name           => ENV['user_email'],
          :password            => ENV['user_email_pass'],
          :authentication       => :plain, 
          :domain               => "grandbash.herokuapp.com" 
        }
      )

  erb :submit
end

get '/dayofevent' do
    @title = 'GrandBash| Day of Grandbash Event'
    prizes= db.exec("SELECT * FROM prizes WHERE winning_number is null order by draw_time asc limit 5")
    erb :dayofevent, :locals => {:prizes => prizes}
end







get '/admin_page' do
   @title = 'GrandBash| Admin Page'
   prizes= db.exec("SELECT * FROM prizes WHERE winning_number is null order by draw_time asc limit  1")
    get_text= db.exec("SELECT text_box FROM text")
    
   erb :admin_page, :locals => {:prizes => prizes,:message =>"",:get_text =>get_text,:edit_text => ""}
end

post '/submitmaintext' do
    text=params[:text_box]
    edit_text= db.exec("SELECT text_box FROM text")
    update_text= db.exec("UPDATE text SET (text_box) = ('#{text}')")
    redirect '/admin_page'
end




post '/winningnumber' do
    dtime= params[:dtime]
    enternumber= params[:enternumber]
    update_number=db.exec("UPDATE prizes SET winning_number='#{enternumber}'where draw_time = '#{dtime}'")
    prizes= db.exec("SELECT * FROM prizes WHERE winning_number is null order by draw_time asc limit  1")   
    if prizes.num_tuples.zero? == false    
       erb :admin_page, :locals => {:prizes => prizes,:message =>"",:get_text =>" ",:update_text =>"",:edit_text => ""}
    else
       erb :admin_page, :locals => {:prizes => prizes,:message =>"Nothing to update at this time",:get_text =>" ",:update_text =>"",:edit_text => ""}
    end
end

get '/numberwon' do
   prizes= db.exec("SELECT * FROM prizes WHERE submit2='#{winning_number}'")  
   erb :numberwon,:locals => {:prizes => prizes}
end
