require 'sinatra'
require 'rubygems'
require 'tilt/erb'
require 'bcrypt'
require 'pony'
require 'bcrypt'
require 'pg'
require_relative "grandbash_functions.rb"
load "./local_env.rb" if File.exists?("./local_env.rb")

db_params={
   host: "grandbash.c4iif5msrrmw.us-west-2.rds.amazonaws.com",
   port:'5432',
   dbname:'grandbash',
   user:ENV['user'],
   password:ENV['password'],    
}

db= PG::Connection.new(db_params)

set :sessions,
    key: ENV['key'],
     #domain: "grandbash.herokuapp.com",
    domain: "localhost",
    path: '/',
    secret: ENV['secret']

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
 

post '/subscribe' do
    email= params[:email]
    check_email = db.exec("SELECT * FROM maillist WHERE email_address = '#{email}'")
       
    if check_email.num_tuples.zero? == false
            erb :mailinglist, :locals => {:message => "You have already joined our mailing list"}
    else
         subscribe=db.exec("insert into maillist(email_address)VALUES('#{email}')")
         erb :mailinglist, :locals => {:message => "Thanks, for joining our mailing list."}
    end
end
    
get '/contact' do
    @title = 'GrandBash| Contact Us'
    erb :contact
end

get '/privacy' do
    @title = 'GrandBash| Refund & Privacy Policy'
    erb :privacy
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

get '/profile' do
    @title = 'GrandBash| User profile'
    erb :profile, :locals => {:message => " ", :message1 => " "}
end

post '/profile' do
    fname = params[:first_name]
    lname = params[:last_name]
    address = params[:address]
    city = params[:city]
    state = params[:state]
    zip = params[:zip]
    email = params[:email]
    phone = params[:phone]
    user_name = params[:user_name]
    user_pass = params[:user_pass]
    
    #This is for creating profile and preventing duplication
    check_username = db.exec("SELECT * FROM users WHERE user_name = '#{user_name}'")
    
    check_email = db.exec("SELECT * FROM users WHERE email = '#{email}'")
    
    hash = BCrypt::Password.create(user_pass, :cost => 11) 
    
    
        if check_username.num_tuples.zero? == false
            erb :profile, :locals => {:message => "That user name already exists", :message1 => " "}
        elsif 
            check_email.num_tuples.zero? == false
            erb :profile, :locals => {:message => " ", :message1 => "That email already exists"}
        else
            db.exec ("INSERT INTO users (name, address, city, state, zipcode, email, user_name, encrypted_password) VALUES ('#{fname}  #{lname}', '#{address}','#{city}', '#{state}', '#{zip}', '#{email}', '#{user_name}', '#{hash}'  )" )
            erb :success, :locals => {:message => "You have successfully created a new profile.", :message1 => " "}
        end
end

post '/login' do
    # Standard Log In
    
    user_name = params[:user_name]
    user_pass = params[:user_pass]
    email = params[:email]
    
    match_login = db.exec("SELECT user_name, encrypted_password, usertype, email FROM users WHERE user_name = '#{user_name}'")
    
        if match_login.num_tuples.zero? == true
            error = erb :login, :locals => {:message => "invalid username and password combination"}
            return error
        end
    
    password = match_login[0]['encrypted_password']
    comparePassword = BCrypt::Password.new(password)
    usertype = match_login[0]['usertype']
    email =  match_login[0]['email']
    
      if match_login[0]['user_name'] == user_name &&  comparePassword == user_pass

      session[:user] = user_name
      session[:usertype] = usertype
          session[:email] = email  
          erb :index, :locals => {:get_text => " "}
      else
      erb :login, :locals => {:message => "invalid username and password combination"}
      end
    redirect '/' 
end

get '/edit_profile' do
    @title = 'GrandBash|Edit Profile' 
    edit_profile = db.exec("SELECT * FROM users where email = '#{session[:email]}' ")    
    erb :edit_profile, :locals => {:edit_profile => edit_profile}
end

post '/edit_profile' do
   name = params[:name]
   address = params[:address]
   city = params[:city]
   state = params[:state]
   zip = params[:zip]
   email = params[:email]
   phone = params[:phone]
           
    update_profile = db.exec ("UPDATE users SET (name, address, city, state, zipcode, email, phone)  =  ('#{name}', '#{address}','#{city}', '#{state}', '#{zip}', '#{email}', '#{phone}' ) WHERE email = '#{email}'" )
    
    redirect '/'
end

get '/success' do
    @title = 'Success'
    erb :success
end

get '/logout' do
  session[:user] = nil
  session[:usertype] = nil
  redirect '/'
end

post '/facebook' do
    @title = 'GrandBash| Facebook Login'    
    name = params[:name]
    email = params[:email]
    
    check_email = db.exec("SELECT * FROM users WHERE email = '#{email}'")
    
    if check_email.count > 0
        puts '#{check_email}'
    else
        facebook_log = db.exec ("INSERT INTO users (open_sso_data, name, email) VALUES ('facebook', '#{name}','#{email}' )" )
    end
    session[:user] = name
    session[:email] = email
    puts "session user: #{session[:user]}"
    puts "session email: #{session[:email]}"
    redirect '/'   
end

post '/google' do
    @title = 'GrandBash|Google Login'
    
    name = params[:gname]
    email = params[:gemail]
    
    check_email = db.exec("SELECT * FROM users WHERE email = '#{email}'")
    
    if check_email.count > 0
        puts '#{check_email}'
    else
        google_log = db.exec ("INSERT INTO users (open_sso_data, name, email) VALUES ('google', '#{name}','#{email}' )" )
    end
    session[:user] = name
    session[:email] = email
    redirect '/'   
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
