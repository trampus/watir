=begin rdoc
   This is FireWatir, Web Application Testing In Ruby using Firefox browser

   Typical usage:
    # include the controller
    require "firewatir"

    # go to the page you want to test
    ff = FireWatir::Firefox.start("http://myserver/mypage")

    # enter "Angrez" into an input field named "username"
    ff.text_field(:name, "username").set("Angrez")

    # enter "Ruby Co" into input field with id "company_ID"
    ff.text_field(:id, "company_ID").set("Ruby Co")

    # click on a link that has "green" somewhere in the text that is displayed
    # to the user, using a regular expression
    ff.link(:text, /green/)

    # click button that has a caption of "Cancel"
    ff.button(:value, "Cancel").click

   FireWatir allows your script to read and interact with HTML objects--HTML tags
   and their attributes and contents.  Types of objects that FireWatir can identify
   include:

   Type         Description
   ===========  ===============================================================
   button       <input> tags, with the type="button" attribute
   check_box    <input> tags, with the type="checkbox" attribute
   div          <div> tags
   form
   frame
   hidden       hidden <input> tags
   image        <img> tags
   label
   link         <a> (anchor) tags
   p            <p> (paragraph) tags
   radio        radio buttons; <input> tags, with the type="radio" attribute
   select_list  <select> tags, known informally as drop-down boxes
   span         <span> tags
   table        <table> tags
   text_field   <input> tags with the type="text" attribute (a single-line
                text field), the type="text_area" attribute (a multi-line
                text field), and the type="password" attribute (a
                single-line field in which the input is replaced with asterisks)

   In general, there are several ways to identify a specific object.  FireWatir's
   syntax is in the form (how, what), where "how" is a means of identifying
   the object, and "what" is the specific string or regular expression
   that FireWatir will seek, as shown in the examples above.  Available "how"
   options depend upon the type of object, but here are a few examples:

   How           Description
   ============  ===============================================================
   :id           Used to find an object that has an "id=" attribute. Since each
                 id should be unique, according to the XHTML specification,
                 this is recommended as the most reliable method to find an
                 object.
   :name         Used to find an object that has a "name=" attribute.  This is
                 useful for older versions of HTML, but "name" is deprecated
                 in XHTML.
   :value        Used to find a text field with a given default value, or a
                 button with a given caption
   :index        Used to find the nth object of the specified type on a page.
                 For example, button(:index, 2) finds the second button.
                 Current versions of FireWatir use 1-based indexing, but future
                 versions will use 0-based indexing.
   :xpath	     The xpath expression for identifying the element.

   Note that the XHTML specification requires that tags and their attributes be
   in lower case.  FireWatir doesn't enforce this; FireWatir will find tags and
   attributes whether they're in upper, lower, or mixed case.  This is either
   a bug or a feature.

   FireWatir uses JSSh for interacting with the browser.  For further information on
   Firefox and DOM go to the following Web page:

   http://www.xulplanet.com/references/objref/

=end

module FireWatir
   include Watir::Exception

   class Firefox
      include FireWatir::Container

      # XPath Result type. 
      # Return only first node that matches the xpath expression.
      # More details: 
      #  "http://developer.mozilla.org/en/docs/DOM:document.evaluate"

    FIRST_ORDERED_NODE_TYPE = 9

###############################################################################
# Description:
#   Starts the firefox browser.
#   On windows this starts the first version listed in the registry.
#
# Input:
#   options  - Hash of any of the following options:
#     :waitTime - Time to wait for Firefox to start. By default it waits for 2
#        seconds.  This is done because if Firefox is not started and we try 
#        to connect to jssh on port 9997 an exception is thrown.
#     :profile  - The Firefox profile to use. If none is specified, Firefox
#         will use the last used profile.
#     :suppress_launch_process - do not create a new firefox process. Connect
#        to an existing one.
#
###############################################################################
    def initialize(options = {})
       jssh_down = false
     
      if(options.kind_of?(Integer))
        options = {:waitTime => options}
      end

      # check for jssh not running, firefox may be open but not with -jssh
      # if its not open at all, regardless of the :suppress_launch_process 
      # option start it error if running without jssh, we don't want to kill 
      # their current window (mac only)

      begin
        set_defaults()
      rescue Watir::Exception::UnableToStartJSShException
        jssh_down = true
      end

      if ( (current_os == :macosx) && 
         (!%x{ps x | grep firefox-bin | grep -v grep}.empty?) )
        raise "Firefox is running without -jssh" if jssh_down
        open_window unless options[:suppress_launch_process]
      elsif not options[:suppress_launch_process]
        launch_browser(options)
      end

      set_defaults()
      get_window_number()
      set_browser_document()
    end

###############################################################################
# inspect -- method
#
###############################################################################
    def inspect
      '#<%s:0x%x url=%s title=%s>' % 
         [self.class, hash*2, url.inspect, title.inspect]
    end

###############################################################################
# launch_browser -- Method
#     This method launches a new firefox browser.
#
# Input:
#     options:  A hash of options.
#        Supported options: :profile, :waitTime
#
# Results:
#     None.
#
###############################################################################
    def launch_browser(options = {})

      if (options[:profile])
        profile_opt = "-no-remote -P #{options[:profile]}"
      else
        profile_opt = ""
      end

      bin = path_to_bin()
      @thread = Thread.new { system("#{bin} -jssh #{profile_opt}") }
      sleep options[:waitTime] || 2

    end
    private :launch_browser

###############################################################################
# start -- method
#     This method creates a new instance of Firefox. Loads the URL and 
#     returns the instance.
# Input:
#     url: url of the page to be loaded.
#
# Results:
#     return a new instance of Firefox.
#
###############################################################################
    def self.start(url)
      ff = Firefox.new
      ff.goto(url)

      return ff
    end

###############################################################################
# get_window_number -- Method
#     This method gets the window number opened.
#
# Input:
#     None.
#
# Results:
#     returns the number of the last window opened.
#
# Notes:
#     Currently: this returns the most recently opened window, which may or may
# not be the current window.
#
###############################################################################
    def get_window_number()
      window_count = 0

      # If at any time a non-browser window like the "Downloads" window
      #   pops up, it will become the topmost window, so make sure we
      #   ignore it.
      window_count = js_eval("getWindows().length").to_i - 1

      while (js_eval("getWindows()[#{window_count}].getBrowser") == '')
        window_count -= 1;
      end

      # now correctly handles instances where only browserless windows are open
      # opens one we can use if count is 0
      if (window_count < 0)
        open_window
        window_count = 1
      end

      @window_index = window_count
    end
    private :get_window_number

###############################################################################
# goto -- Method
#     Loads the given url in the browser. Waits for the page to get loaded.
#
# Input:
#     url: The url to load in the browser.
#
# Results:
#     None.
#
###############################################################################
    def goto(url)
      get_window_number()
      set_browser_document()
      js_eval "#{browser_var}.loadURI(\"#{url}\")"
      wait()
    end

###############################################################################
# back -- Method
#     Loads the previous page (if there is any) in the browser. Waits for 
#        the page to get loaded.
#
# Input:
#     None.
#
# Results:
#     None.
#
###############################################################################
    def back()
      js_eval "if(#{browser_var}.canGoBack) #{browser_var}.goBack()"
      wait()
    end

###############################################################################
# forward -- Method
#     Loads the next page (if there is any) in the browser. Waits for the 
#     page to get loaded.
#
# Input:
#     None.
#
# Results:
#     None.
#
###############################################################################
    def forward()
      js_eval "if(#{browser_var}.canGoForward) #{browser_var}.goForward()"
      wait()
    end

###############################################################################
# refresh -- Method
#     Reloads the current page in the browser. Waits for the page to 
#     get loaded.
#
# Input:
#     None.
#
# Results:
#     None.
#
###############################################################################
    def refresh()
      js_eval("#{browser_var}.reload()")
      wait()
    end

###############################################################################
# execute_script -- Method
#     Executes the given JavaScript string.
#
# Input:
#     source: The js source to execute.
#
# Results:
#     returns the result of the script.
#
###############################################################################
    def execute_script(source)
      result = js_eval(source.to_s())
      wait()

      return result
    end

   public :execute_script

###############################################################################
# set_defaults -- Method
#     This function creates a new socket at port 9997 and sets the default 
#     values for instance and class variables.  Generatesi 
#     UnableToStartJSShException if cannot connect to jssh even after 3 tries.
#
# Input:
#     no_of_tries: The number of times to retry.
#
# Results:
#     None.
#
###############################################################################
   def set_defaults(no_of_tries = 0)
      # JSSH listens on port 9997. Create a new socket to connect to port 9997.
      begin
         $jssh_socket = TCPSocket::new(MACHINE_IP, "9997")
         $jssh_socket.sync = true
         read_socket()
      rescue
        no_of_tries += 1
        retry if no_of_tries < 3
        raise UnableToStartJSShException, "Unable to connect to machine : "+
         "#{MACHINE_IP} on port 9997. Make sure that JSSh is properly "+
         "installed and Firefox is running with '-jssh' option"
      end
      @error_checkers = []
   end

   private :set_defaults

###############################################################################
# set_browser_document -- Method
#     Sets the document, window and browser variables to point to correct 
#     object in JSSh.
#
# Input:
#     None.
#
# Results:
#     None.
#
# Notes:
# Add eventlistener for browser window so that we can reset the document back 
# whenever there is redirect or browser loads on its own after some time. 
# Useful when you are searching for flight results etc and page goes to search
# page after that it goes automatically to results page.
# Details : 
# http://zenit.senecac.on.ca/wiki/index.php/Mozilla.dev.tech.xul#What_is_an_example_of_addProgressListener.3F
#
###############################################################################
   def set_browser_document
      doc = document_var()
      browser = browser_var()
      body = body_var()
      window = ""

      jssh_command = <<JS   
   var listObj = new Object();
   listObj.wpl = Components.interfaces.nsIWebProgressListener;
   listObj.QueryInterface = function(aIID) {
      if (aIID.equals(listObj.wpl) ||
         aIID.equals(Components.interfaces.nsISupportsWeakReference) ||
         aIID.equals(Components.interfaces.nsISupports)) {
         return this;
      }

      throw Components.results.NS_NOINTERFACE;
   }; // set function to locate the object via QueryInterface

   listObj.onStateChange = function(aProgress, aRequest, aFlag, aStatus) {
      if (aFlag & listObj.wpl.STATE_STOP) {
         if ( aFlag & listObj.wpl.STATE_IS_NETWORK ) {
            #{doc} = #{browser}.contentDocument;
            #{body} = #{doc}.body;
         }
      }
   };
   // add function to be called when window state is change. 
   // When state is STATE_STOP & STATE_IS_NETWORK then only everything is 
   // loaded. Now we can reset our variables.
JS

      js_eval(jssh_command)

      window = window_var()
      jssh_command = <<JS
   var #{window} = getWindows()[#{@window_index}];
   var #{browser} = #{window}.getBrowser();
   
   // Add listener create above to browser object
   #{browser}.addProgressListener(listObj, Components.interfaces.nsIWebProgress.NOTIFY_STATE_WINDOW);

   var #{doc} = #{browser}.contentDocument;
   var #{body} = #{doc}.body;

JS
      js_eval(jssh_command)

      jssh_command = <<JS
   var #{doc} = #{browser}.contentDocument;
   #{doc}.title
JS
      @window_title = js_eval(jssh_command)
      @window_url = js_eval("#{doc}.URL")

   end

###############################################################################
# window_var -- Method
#     This method just gets the javascript window var name.
#
# Input:
#     None.
#
# Results:
#     Always returns the javascript window var name in string format.
#
###############################################################################
   def window_var
      return "window"
   end

   public :window_var

###############################################################################
# browser_var -- Method
#     This method just gets the javascript browser var name.
#
# Input:
#     None.
#
# Results:
#     Always returns the javascript browser var name in string format.
#
###############################################################################
   def browser_var
      return "browser"
   end

###############################################################################
# document_var -- Method
#     This method just gets the javascript document var name.
#
# Input:
#     None.
#
# Results:
#     Always returns the javascript document var name in string format.
#
###############################################################################
   def document_var # unfinished
      return "document"
   end

###############################################################################
# body_var -- Method
#     This method just gets the javascript body var name.
#
# Input:
#     None.
#
# Results:
#     Always returns the javascript body var name in string format.
#
###############################################################################
   def body_var # unfinished
      return "body"
   end


###############################################################################
# close -- Method
#     This function trys to close the current firefox window.
#
# Input:
#     None.
#
# Results:
#     None.
#
###############################################################################
   def close

      if (js_eval("getWindows().length").to_i() == 1)
         js_eval("getWindows()[0].close()")

         if (current_os == :macosx)
            %x{ osascript -e 'tell application "Firefox" to quit' }
         end

         # wait for the app to close properly
         @thread.join if @thread
      else
        # Check if window exists, because there may be the case that it has 
        # been closed by click event on some element.
        # For e.g: Close Button, Close this Window link etc.
        window_number = find_window(:url, @window_url)

        # If matching window found. Close the window.
        if (window_number > 0)
          js_eval("getWindows()[#{window_number}].close()")
        end

      end
   end

   public :close
   
###############################################################################
# Closes -- Method
#     Closes all firefox windows.
# 
# Input:
#     None.
#
# Results:
#     None.
#
###############################################################################
   def close_all
      total_windows = js_eval("getWindows().length").to_i

       # start from last window  
       while (total_windows > 0) do
         js_eval "getWindows()[#{total_windows - 1}].close()"
         total_windows = total_windows - 1
       end

        if (current_os == :macosx)
            %x{ osascript -e 'tell application "Firefox" to quit' }
        end  

        if (current_os == :windows)
            system("taskkill /im firefox.exe /f /t >nul 2>&1")
        end
    end

    public :close_all

###############################################################################
# attach -- Method
#     Used for attaching pop up window to an existing Firefox window, 
#     either by url or title.
#
# Example:
#     ff.attach(:url, 'http://www.google.com')
#     ff.attach(:title, 'Google')
#
# Output:
#   Instance of newly attached window.
###############################################################################
   def attach(how, what)
      window_number = -1

      if ($VERBOSE)
         $stderr.puts("Warning: #{self.class}.attach is experimental.\n")
      end

      window_number = find_window(how, what)
      if (window_number < 0)
         emsg = "Unable to locate window, using #{how} and #{what}"
         raise NoMatchingWindowFoundException.new(emsg)
      elsif (window_number > -1)
        @window_index = window_number
        set_browser_document()
      end

      return self
   end

###############################################################################
# self.attach -- Class Method
#     To return a browser object if a window matches for how and what.
#     Window can be referenced by url or title.  The second argument can be 
#     either a string or a regular expression.
#
# Input:
#     how: :url or :title
#     what: the value for how.
#
# Results:
#     returns a new browser instance or raises and exception.
#
# Example:
#     Watir::Browser.attach(:url, 'http://www.google.com')
#     Watir::Browser.attach(:title, 'Google')
###############################################################################
   def self.attach(how, what)
      br = new :suppress_launch_process => true # don't create window
      br.attach(how, what)
      return br
   end


###############################################################################
# open_window -- Method   
#     This method loads up a new window in an existing process.
#     Watir::Browser.attach() with no arguments passed the attach method will 
#     create a new window this will only be called one time per instance 
#     we're only ever going to run in 1 window.
#
# Input:
#     None.
#
# Results:
#     returns -1 on failure or the index into jssh's getWindows array for a
#        newly created window.
#
###############################################################################
   def open_window
      jssh_command = ""
      window_number = -1

      if (@opened_new_window)
         return @opened_new_window
      end

      jssh_command = <<JS
   var windows = getWindows();
   var window = windows[0];
   
   window.open();
   var windows = getWindows(); 
   var window_number = windows.length - 1;
   window_number;
   
JS
      window_number = js_eval(jssh_command).to_i()
      @opened_new_window = window_number

      if (window_number < 0)
         window_number = -1
      end
   
      return window_number
    end

    private :open_window

###############################################################################
# find_window -- Method
#     Return the window index of the browser window with the given title or url.
#
# Input:
#     how: can be either :url or :title
#     what: string or regexp
#
# Results
#     returns -1 on error else an index into the jssh window array returned
#        from getWindows().
#
# Notes:
#     Starts searching windows in reverse order so that we attach/find the 
#     latest opened window.
#
###############################################################################
   def find_window(how, what)
      jssh_command = <<JS
   var windows = getWindows();
   var window_number = false;
   var found = false;
  
   for(var i = windows.length - 1; i >= 0; i--)
   {
      var attribute = '';
      if(typeof(windows[i].getBrowser) != 'function')
      {
         continue;
      }

      var browser = windows[i].getBrowser();
      if (!browser)
      {
         continue;
      }

      if ("#{how}" == "url")
      {
         attribute = browser.contentDocument.URL;
      }

      if ("#{how}" == "title")
      {
         attribute = browser.contentDocument.title;
      }

JS
      if (what.class == Regexp)
         jssh_command << "\tvar regExp = new RegExp(#{what.inspect});\n" +
            "\tfound = regExp.test(attribute);\n"
      else
        jssh_command << "\tfound = (attribute == \"#{what}\");\n"
      end

      jssh_command += <<JS     
      if(found) {
         window_number = i;
         break;
      }
   }

   window_number;
JS
      window_number = js_eval(jssh_command).to_s()
      return window_number == 'false' ? -1 : window_number.to_i()
    end

    private :find_window

###############################################################################
# contains_text -- Method
#     Matches the given text with the current text shown in the browser.
#
# Input:
#     target: Text to match. Can be a string or regex.
#
# Results:
#     Returns the index if the specified text was found.
#     Returns matchdata object if the specified regexp was found.
#     Raises an exception on an unsupported target type.
#
###############################################################################
   def contains_text(target)  
      result = nil

      case target
         when Regexp
            result = self.text.match(target)
         when String
            result = self.text.index(target)
         else
            raise TypeError, "Argument #{target} should be a string or regexp."
      end

      return result
    end

###############################################################################
# url -- Method
#     Gets the browser's current url, and sets instants var.
#
# Input:
#     None.
# 
# Results:
#     Returns the url of the page currently loaded in the browser.
#
###############################################################################
    def url
      @window_url = js_eval "#{document_var}.URL"
      return @window_url
    end

###############################################################################
# title -- Method
#     Gets the current browser title, and sets instants var.
#
# Input:
#     None.
#
# Results:
#     Returns the title of the page currently loaded in the browser.
#
###############################################################################
   def title
      @window_title = js_eval "#{document_var}.title"
      return @window_title
   end

###############################################################################
# status -- Method   
#     Gets the Status of the page currently loaded in the browser from 
#        statusbar.
#
# Input:
#     None.
#
# Results:
#     returns the current browser page status.  Can be an empty string.
#
###############################################################################
   def status
      status = ""

      status = js_eval("#{window_var}.status")
      if (status.empty?)
         status = js_eval("#{window_var}.XULBrowserWindow.statusText;")
      end

      return status
   end

###############################################################################
# html -- Method
#     Gets the html source for the page currently loaded in the browser.
#
# Input:
#     None.
#
# Results:
#     returns the html of the page currently loaded in the browser.
#
###############################################################################
   def html
      result = ""
         
      result = js_eval("var htmlelem = #{document_var}.getElementsByTagName"+
         "('html')[0]; htmlelem.innerHTML")

      result = "<html>\n#{result}\n</html>"
      
      return result
   end

###############################################################################
# text -- Method
#     Gets the page text from the currently loaded browser page.
#
# Input:
#     None.
#
# Results:
#     returns the text of the page currently loaded in the browser.
#
###############################################################################
   def text
      txt = ""

      txt = js_eval("#{body_var}.textContent").strip()
      return txt
   end

###############################################################################
# Maximize -- Method
#     Maximizes the current browser window.
#
# Input:
#     None.
#
# Results:
#     None.
#
###############################################################################
   def maximize()
      js_eval("#{window_var}.maximize()")
   end

###############################################################################
# Minimize -- Method
#     Minimizes the current browser window.
#
# Input: 
#     None.
#
# Results:
#     None.
#
###############################################################################
   def minimize()
      js_eval("#{window_var}.minimize()")
   end

###############################################################################
# wait -- Method
#     Waits for the page to get loaded.
#
# Input:
#     last_url: 
###############################################################################
    def wait(last_url = nil)
      jssh_command = ""
      url = ""
      isLoadingDocument = ""
      wait_time = 0

      start = Time.now()
      js = "#{browser_var}=#{window_var}.getBrowser(); #{browser_var}"+
         ".webProgress.isLoadingDocument;"

      while (isLoadingDocument != "false")
         isLoadingDocument = js_eval(js)

         # Raise an exception if the page fails to load
         if ( (Time.now - start) > 300 )
            raise "Page Load Timeout"
         end
      end

      # If the redirect is to a download attachment that does not reload this
      # page, this method will loop forever. Therefore, we need to ensure that
      # if this method is called twice with the same URL, we simply accept 
      # that we're done.

      url = js_eval("#{browser_var}.contentDocument.URL")
      if(url != last_url)
      # Check for Javascript redirect. As we are connected to Firefox via JSSh.
      # Jssh doesn't detect any javascript redirects so check it here.
      # If page redirects to itself that this code will enter in infinite loop.
      # So we currently don't wait for such a page.
      # wait variable in JSSh tells if we should wait more for the page to get
      # loaded or continue. -1 means page is not redirected. Anyother positive
      # values means wait.

      jssh_command = <<JS
   var wait = -1;
   var meta = null;

   meta = #{browser_var}.contentDocument.getElementsByTagName('meta');
   if(meta != null)
   {
      var doc_url = #{browser_var}.contentDocument.URL;
 
      for(var i=0; i< meta.length;++i)
      {
         var content = meta[i].content;
         var regex = new RegExp(\"^refresh$\", \"i\");
if(regex.test(meta[i].httpEquiv))
 {
    var arrContent = content.split(';');
   var redirect_url = null;
   if(arrContent.length > 0)
   {
      if(arrContent.length > 1)
         redirect_url = arrContent[1];

      if(redirect_url != null)
      {
         regex = new RegExp(\"^.*\" + redirect_url + \"$\");
         if(!regex.test(doc_url))
         {
            wait = arrContent[0];
          }
       }
       break;
    }
 }
}
  }
  wait;
JS

        wait_time = js_eval(jssh_command).to_i()
         begin
            if (wait_time != -1)
               sleep(wait_time)
               # Call wait again. In case there are multiple redirects.
               js_eval("#{browser_var} = #{window_var}.getBrowser()")
               wait(url)
             end
         rescue
         end
      end

      set_browser_document()
      run_error_checks()
      return self
    end

###############################################################################
# add_checker -- Method
#     Adds an error checker that gets called on every page load.
#
# Intput:    
#     checker: a Proc object.
#
# Results:
#     None.
#
###############################################################################
   def add_checker(checker)
      @error_checkers << checker
   end

###############################################################################
# disable_checker -- Method
#     Deletes an error checker from global list.
#
# Input:
#     checker: a Proc object that is to be deleted.
#
# Results:
#     None.
#
###############################################################################
   def disable_checker(checker)
      @error_checkers.delete(checker)
   end

###############################################################################
# run_error_checks -- Method
#     Runs the predefined error checks. This is automatically called on 
#     every page load.
#
# Input:
#     None.
#
# Results:
#     None.
#
###############################################################################
   def run_error_checks
      @error_checkers.each { |e| e.call(self) }
   end

###############################################################################
# startClicker -- Method
#     Tells FireWatir to click javascript button in case one comes after 
#     performing some action on an element. Matches text of pop up with one if
#     supplied as parameter. If text matches clicks the button else stop 
#     script execution until pop up is dismissed by manual intervention.
#    
# Input:
#     button: JavaScript button to be clicked. Values can be OK or Cancel.
#     waitTime: Time to wait for pop up to come. Not used just for 
#        compatibility with Watir.
#
#     userInput: Not used just for compatibility with Watir.
#     text: Text that should appear on pop up.
#
# Results:
#     None.
#
###############################################################################
   def startClicker(button, waitTime = 1, userInput = nil, text = nil)
      jssh_command = "var win = #{browser_var}.contentWindow;\n"

      if (button =~ /ok/i)
         jssh_command = <<JS 
   var popuptext = '';
   var old_alert = win.alert;
   var old_confirm = win.confirm;

   win.alert = function(param) {
JS
         if(text != nil)
            jssh_command += <<JS          
      if(param == \"#{text}\") {
         popuptext = param;
         return true;
      } else {
         popuptext = param;
         win.alert = old_alert;
         win.alert(param);
      }
JS
         else
            jssh_command += "popuptext = param; return true;\n"
         end
         
         jssh_command += "};\n\t\twin.confirm = function(param) {"
         
         if (text != nil)
            jssh_command += <<JS
      if(param == "#{text}") {
         popuptext = param;
         return true;
      } else {
         win.confirm = old_confirm;
         win.confirm(param);
      }
JS
         else
            jssh_command += "\t\tpopuptext = param; return true;\n"
         end
        
         jssh_command << "};\n"

      elsif (button =~ /cancel/i)
         jssh_command = "var old_confirm = win.confirm;\n" +
            "win.confirm = function(param) {\n"
         if(text != nil)
            jssh_command += <<JS
   if(param == "#{text}") {
      popuptext = param;
      return false;
   } else {
      win.confirm = old_confirm;
      win.confirm(param);
   }
JS
         else
            jssh_command += "popuptext = param; return false;\n"
         end
         jssh_command += "};\n"
      end
      
      js_eval(jssh_command)
   end

###############################################################################
# get_popup_text -- Method
#     Get the text of javascript pop up in case it comes.
#
# Input:
#     None.
#
# Results:
#   returns the text shown in javascript pop up in a string.
#
###############################################################################
   def get_popup_text()
      results = ""
      
      results = js_eval("popuptext")
      # reset the variable
      js_eval("popuptext = ''")
      return results
   end

###############################################################################
# document -- Method    
#     Gets the document element of the page currently loaded in the browser.
#
# Input:
#     None.
#
# Results:
#     returns the doc element.
#
###############################################################################
   def document()
      doc = nil

      doc = Document.new(self)
      return doc
   end

###############################################################################
# element_by_xpath -- Method
#     Gets the first element that matches the given xpath expression or query.
#
# Input: 
#     xpath: The xpath to the element to get.
#
# Results:
#     returns the element.
#
###############################################################################
   def element_by_xpath(xpath)
      temp = Element.new(nil, self)
      element_name = temp.element_by_xpath(self, xpath)
      return element_factory(element_name)
   end

###############################################################################
# element_factory -- Method
#     Gets the object of correct element class while using XPath to get 
#     the element.
#
# Input:
#     element_name: The name of the element to get.
#
# Results:
#     returns a new element class.
#   
###############################################################################
   def element_factory(element_name)
      jssh_type = nil
      candidate_class = nil
      firewatir_class = nil
      input_type = nil
      klass = nil

      jssh_type = Element.new(element_name,self).element_type
      candidate_class = jssh_type =~ /HTML(.*)Element/ ? $1 : ''

      if (candidate_class == 'Input')
         input_type = js_eval("#{element_name}.type").downcase.strip
         firewatir_class = input_class(input_type)
      else
         firewatir_class = jssh2firewatir(candidate_class)
      end

      klass = FireWatir.const_get(firewatir_class)

      case klass
         when Element
            klass.new(element_name,self)
         when CheckBox
            klass.new(self,:jssh_name,element_name,["checkbox"])
         when Radio
            klass.new(self,:jssh_name,element_name,["radio"])
         else
            klass.new(self,:jssh_name,element_name)
      end
      
      return klass
   end
   
   private :element_factory

###############################################################################
# input_class -- Method
#     Gets the class name for element of input type depending upon its type 
#     like checkbox, radio etc.
#
# Input:
#     input_type: The input type name for the class to get.
#
# Returns:
#     returns the hash value for the input_type.
#
###############################################################################
   def input_class(input_type)
      hash = {
         'select-one' => 'SelectList',
         'select-multiple' => 'SelectList',
         'text' => 'TextField',
         'password' => 'TextField',
         'textarea' => 'TextField',
         # TODO when there's no type, it's a TextField
         'file' => 'FileField',
         'checkbox' => 'CheckBox',
         'radio' => 'Radio',
         'reset' => 'Button',
         'button' => 'Button',
         'submit' => 'Button',
         'image' => 'Button'
      }
      hash.default = 'Element'

      return hash[input_type]
   end
   
   private :input_class

###############################################################################
# jssh2firewatir -- Method
#     For a provided element type returned by JSSh like HTMLDivElement.
#
# Input:
#     candidate_class:
#
# Results:
#     returns its corresponding class in Firewatir.
#
###############################################################################
   def jssh2firewatir(candidate_class)
      hash = {
         'Div' => 'Div',
         'Button' => 'Button',
         'Frame' => 'Frame',
         'Span' => 'Span',
         'Paragraph' => 'P',
         'Label' => 'Label',
         'Form' => 'Form',
         'Image' => 'Image',
         'Table' => 'Table',
         'TableCell' => 'TableCell',
         'TableRow' => 'TableRow',
         'Select' => 'SelectList',
         'Link' => 'Link',
         'Anchor' => 'Link' # FIXME is this right?
         #'Option' => 'Option' #Option uses a different constructor
         }

      hash.default = 'Element'
      return hash[candidate_class]
    end

    private :jssh2firewatir

###############################################################################
# elements_by_xpath -- Method
#     Gets the array of elements that matches the xpath query.
#
# Input:
#     Xpath expression or query.
#
# Results:
#     returns an array of elements matching xpath query.
#
###############################################################################
   def elements_by_xpath(xpath)
      element = Element.new(nil, self)
      elem_names = element.elements_by_xpath(self, xpath)
      elem_names.inject([]) {|elements, name| elements << element_factory(name)}
   end

###############################################################################
# show_forms -- Method
#     Show all the forms available on the page.
#
# Input:
#     print: true/false, weather to print to stdout or not.
#
# Results:
#     returns an array of info about all the forms on the page.
#
###############################################################################
   def show_forms(print = true)
      forms = nil
      count = 0

      forms = Document.new(self).get_forms()

      if (print)
         count = forms.length
         puts "There are #{count} forms"
         for i in 0..count - 1 do
            puts "Form name: " + forms[i].name
            puts "       id: " + forms[i].id
            puts "   method: " + forms[i].attribute_value("method")
            puts "   action: " + forms[i].action
         end
      end

      return forms
   end
   alias showForms show_forms

###############################################################################
# show_images -- Method
#   Show all the images available on the page.  Prints info about all the 
#     images on the current page. 
#
# Input:
#     print: true/false, weather to print to stdout or not.
#
# Results:
#   returns an array of images.
#
###############################################################################
   def show_images(print = true)
      images = Document.new(self).get_images

      if (print)
         puts "There are #{images.length} images"
         index = 1
         images.each do |l|
            puts "image: name: #{l.name}"
            puts "         id: #{l.id}"
            puts "        src: #{l.src}"
            puts "      index: #{index}"
            index += 1
         end
      end

      return images
   end
   alias showImages show_images

###############################################################################
# show_links -- Method
#   Prints info about all the links available on the page.
#
# Input:
#     print: true/false, weather to print to stdout or not.
#
# Results:
#     returns an array of info about all the links on a page.
#
###############################################################################
   def show_links(print = true)
      links = Document.new(self).get_links

      if (print)
         puts "There are #{links.length} links"
         index = 1
         links.each do |l|
            puts "link:  name: #{l.name}"
            puts "         id: #{l.id}"
            puts "       href: #{l.href}"
            puts "      index: #{index}"
            index += 1
         end
      end

      return links
   end
   alias showLinks show_links

###############################################################################
# show_divs -- Method
#    all the divs available on the page.
#
# Input:
#     print: true/false, weather to print to stdout or not.
#
# Output:
#     returns an array of all of the divs in the current page.
#
###############################################################################
   def show_divs(print = true)
      divs = Document.new(self).get_divs

      if (print)
         puts "There are #{divs.length} divs"
         index = 1
         divs.each do |l|
            puts "div:   name: #{l.name}"
            puts "         id: #{l.id}"
            puts "      class: #{l.className}"
            puts "      index: #{index}"
            index += 1
         end
      end

      return divs
   end
   alias showDivs show_divs

###############################################################################
# show_tables -- Method
#     Show all the tables available on the page.
#
# Input:
#     print: true/false, weather to print to stdout or not.
#
# Output:
#     returns an array of tables.
#
###############################################################################
   def show_tables(print = true)
      tables = Document.new(self).get_tables

      if (print)
         puts "There are #{tables.length} tables"
         index = 1
         tables.each do |l|
            puts "table:   id: #{l.id}"
            puts "       rows: #{l.row_count}"
            puts "    columns: #{l.column_count}"
            puts "      index: #{index}"
            index += 1
         end
      end

      return tables
   end
   alias showTables show_tables

###############################################################################
# show_pres -- Method
#   Show all the pre elements available on the page.
#
# Input:
#     print: true/false, weather to print to stdout or not.
#
# Output:
#     returns an array of all the pres.
#
###############################################################################
   def show_pres(print = true)
      pres = Document.new(self).get_pres

      if (print)
         puts "There are #{pres.length} pres"
         index = 1
         pres.each do |l|
            puts "pre:     id: #{l.id}"
            puts "       name: #{l.name}"
            puts "      index: #{index}"
            index += 1
         end
      end

      return pres
   end
   alias showPres show_pres

###############################################################################
# show_spans -- Method
#   Show all the spans available on the page.
#
# Input:
#     print: true/false, weather to print to stdout or not.
#
# Output:
#     returns an array of spans
#
###############################################################################
   def show_spans(print = true)
      spans = Document.new(self).get_spans

      if (print)
         puts "There are #{spans.length} spans"
         index = 1
         spans.each do |l|
            puts "span:  name: #{l.name}"
            puts "         id: #{l.id}"
            puts "      class: #{l.className}"
            puts "      index: #{index}"
            index += 1
         end
      end

      return spans
   end
   alias showSpans show_spans

###############################################################################
# show_labels -- Method
#   Show all the labels available on the page.
#
# Input:
#     print: true/false, weather to print to stdout or not.
#
# Output:
#     returns an array of labels.
#
###############################################################################
   def show_labels(print = true)
      labels = Document.new(self).get_labels
   
      if (print)
         puts "There are #{labels.length} labels"
         index = 1
         labels.each do |l|
            puts "label: name: #{l.name}"
            puts "         id: #{l.id}"
            puts "        for: #{l.for}"
            puts "      index: #{index}"
            index += 1
         end
      end

      return labels
   end
   alias showLabels show_labels

###############################################################################
# show_frames -- Method
#     Show all the frames available on the page. Doesn't show nested frames.
#
# Input:
#     print: true/false, weather to print to stdout or not.
#
# Output:
#     returns an array of frames
#
###############################################################################
   def show_frames(print = true)
      jssh_command = "var frameset = #{window_var}.frames;
                            var elements_frames = new Array();
                            for(var i = 0; i < frameset.length; i++)
                            {
                                var frames = frameset[i].frames;
                                for(var j = 0; j < frames.length; j++)
                                {
                                    elements_frames.push(frames[j].frameElement);
                                }
                            }
                            elements_frames.length;"

      length = js_eval(jssh_command).to_i
      frames = Array.new(length)
      for i in 0..length - 1 do
        frames[i] = Frame.new(self, :jssh_name, "elements_frames[#{i}]")
      end

      if (print)
         for i in 0..length - 1 do
            puts "frame: name: #{frames[i].name}"
            puts "      index: #{i+1}"
         end
      end

      return frames
    end
    alias showFrames show_frames

    private

###############################################################################
###############################################################################
    def path_to_bin
      path = case current_os()
             when :windows
               path_from_registry
             when :macosx
               path_from_spotlight
             when :linux
               `which firefox`.strip
             end

      raise "unable to locate Firefox executable" if path.nil? || path.empty?

      path
    end

###############################################################################
###############################################################################
    def current_os
      return @current_os if defined?(@current_os)

      platform = RUBY_PLATFORM =~ /java/ ? Java::java.lang.System.getProperty("os.name") : RUBY_PLATFORM

      @current_os = case platform
                    when /mingw32|mswin|windows/i
                      :windows
                    when /darwin|mac os/i
                      :macosx
                    when /linux/i
                      :linux
                    end
    end

###############################################################################
###############################################################################
    def path_from_registry
      require 'win32/registry.rb'
      lm = Win32::Registry::HKEY_LOCAL_MACHINE
      lm.open('SOFTWARE\Mozilla\Mozilla Firefox') do |reg|
        reg1 = lm.open("SOFTWARE\\Mozilla\\Mozilla Firefox\\#{reg.keys[0]}\\Main")
        if entry = reg1.find { |key, type, data| key =~ /pathtoexe/i }
          return entry.last
        end
      end
    rescue LoadError
      if RUBY_PLATFORM =~ /java/
        return(ENV['FIREFOX_HOME'] or raise(
          NotImplementedError,
          'No Registry support in this JRuby; upgrade or set FIREFOX_HOME'))
      else
        raise
      end
    end

###############################################################################
###############################################################################
    def path_from_spotlight
      ff = %x[mdfind 'kMDItemCFBundleIdentifier == "org.mozilla.firefox"']
      ff = ff.empty? ? '/Applications/Firefox.app' : ff.split("\n").first

      "#{ff}/Contents/MacOS/firefox-bin"
    end

  end # Firefox
end # FireWatir
