if not modules then modules = { } end modules ['mtx-server'] = {
    version   = 1.001,
    comment   = "companion to mtxrun.lua",
    author    = "Hans Hagen & Taco Hoekwater",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local helpinfo = [[
<?xml version="1.0"?>
<application>
 <metadata>
  <entry name="name">mtx-server</entry>
  <entry name="detail">Simple Webserver For Helpers</entry>
  <entry name="version">0.10</entry>
 </metadata>
 <flags>
  <category name="basic">
   <subcategory>
    <flag name="start"><short>start server</short></flag>
    <flag name="port"><short>port to listen to</short></flag>
    <flag name="root"><short>server root</short></flag>
    <flag name="scripts"><short>scripts sub path</short></flag>
    <flag name="index"><short>index file</short></flag>
    <flag name="auto"><short>start on own path</short></flag>
   </subcategory>
  </category>
 </flags>
</application>
]]

local application = logs.application {
    name     = "mtx-server",
    banner   = "Simple Webserver For Helpers 0.10",
    helpinfo = helpinfo,
}

local tonumber, tostring, loadfile, type = tonumber, tostring, loadfile, type
local find, gsub = string.find, string.gsub
local joinpath, filesuffix, dirname, is_qualified_path = file.join, file.suffix, file.dirname, file.is_qualified_path
local loaddata = io.loaddata
local P, C, patterns, lpegmatch = lpeg.P, lpeg.C, lpeg.patterns, lpeg.match
local formatters = string.formatters
local urlhashed, urlquery = url.hashed, url.query
local report = application.report
local gettime = os.gettimeofday or os.clock

scripts           = scripts           or { }
scripts.webserver = scripts.webserver or { }

local socket = socket or require("socket")
----- http   = http   or require("socket.http") -- not needed

-- The following two lists are taken from webrick (ruby) and
-- extended with a few extra suffixes.

local mimetypes = {
    ai    = 'application/postscript',
    asc   = 'text/plain',
    avi   = 'video/x-msvideo',
    bin   = 'application/octet-stream',
    bmp   = 'image/bmp',
    bz2   = 'application/x-bzip2',
    cer   = 'application/pkix-cert',
    class = 'application/octet-stream',
    crl   = 'application/pkix-crl',
    crt   = 'application/x-x509-ca-cert',
    css   = 'text/css',
    dms   = 'application/octet-stream',
    doc   = 'application/msword',
    dvi   = 'application/x-dvi',
    eps   = 'application/postscript',
    etx   = 'text/x-setext',
    exe   = 'application/octet-stream',
    gif   = 'image/gif',
    gz    = 'application/x-tar',
    hqx   = 'application/mac-binhex40',
    htm   = 'text/html',
    html  = 'text/html',
    jpe   = 'image/jpeg',
    jpeg  = 'image/jpeg',
    jpg   = 'image/jpeg',
    lha   = 'application/octet-stream',
    lzh   = 'application/octet-stream',
    mov   = 'video/quicktime',
    mpe   = 'video/mpeg',
    mpeg  = 'video/mpeg',
    mpg   = 'video/mpeg',
    pbm   = 'image/x-portable-bitmap',
    pdf   = 'application/pdf',
    pgm   = 'image/x-portable-graymap',
    png   = 'image/png',
    pnm   = 'image/x-portable-anymap',
    ppm   = 'image/x-portable-pixmap',
    ppt   = 'application/vnd.ms-powerpoint',
    ps    = 'application/postscript',
    qt    = 'video/quicktime',
    ras   = 'image/x-cmu-raster',
    rb    = 'text/plain',
    rd    = 'text/plain',
    rgb   = 'image/x-rgb',
    rtf   = 'application/rtf',
    sgm   = 'text/sgml',
    sgml  = 'text/sgml',
    snd   = 'audio/basic',
    tar   = 'application/x-tar',
    tgz   = 'application/x-tar',
    tif   = 'image/tiff',
    tiff  = 'image/tiff',
    txt   = 'text/plain',
    xbm   = 'image/x-xbitmap',
    xls   = 'application/vnd.ms-excel',
    xml   = 'text/xml',
    xpm   = 'image/x-xpixmap',
    xwd   = 'image/x-xwindowdump',
    zip   = 'application/zip',
}

local messages = {
    [100] = 'Continue',
    [101] = 'Switching Protocols',
    [200] = 'OK',
    [201] = 'Created',
    [202] = 'Accepted',
    [203] = 'Non-Authoritative Information',
    [204] = 'No Content',
    [205] = 'Reset Content',
    [206] = 'Partial Content',
    [300] = 'Multiple Choices',
    [301] = 'Moved Permanently',
    [302] = 'Found',
    [303] = 'See Other',
    [304] = 'Not Modified',
    [305] = 'Use Proxy',
    [307] = 'Temporary Redirect',
    [400] = 'Bad Request',
    [401] = 'Unauthorized',
    [402] = 'Payment Required',
    [403] = 'Forbidden',
    [404] = 'Not Found',
    [405] = 'Method Not Allowed',
    [406] = 'Not Acceptable',
    [407] = 'Proxy Authentication Required',
    [408] = 'Request Timeout',
    [409] = 'Conflict',
    [410] = 'Gone',
    [411] = 'Length Required',
    [412] = 'Precondition Failed',
    [413] = 'Request Entity Too Large',
    [414] = 'Request-URI Too Large',
    [415] = 'Unsupported Media Type',
    [416] = 'Request Range Not Satisfiable',
    [417] = 'Expectation Failed',
    [500] = 'Internal Server Error',
    [501] = 'Not Implemented',
    [502] = 'Bad Gateway',
    [503] = 'Service Unavailable',
    [504] = 'Gateway Timeout',
    [505] = 'HTTP Version Not Supported',
}

local f_content_length = formatters["Content-Length: %s\r\n"]
local f_content_type   = formatters["Content-Type: %s\r\n"]
local f_error_title    = formatters["<head><title>%s %s</title></head><html><h2>%s %s</h2></html>"]

local handlers = { }

local function errormessage(client,configuration,n)
    local data = f_error_title(n,messages[n],n,messages[n])
    report("handling error %s: %s",n,messages[n])
    handlers.generic(client,configuration,data,nil,true)
end

local validpaths, registered = { }, { }

function scripts.webserver.registerpath(name)
    if not registered[name] then
        local cleanname = gsub(name,"%.%.","deleted-parent")
        report("registering path: %s",cleanname)
        validpaths[#validpaths+1] = cleanname
        registered[name] = true
    end
end

function handlers.generic(client,configuration,data,suffix,iscontent)
    local name = data
    if not iscontent then
        report("requested file: %s",name)
        local fullname = joinpath(configuration.root,name)
        data = loaddata(fullname) or ""
        if data == "" then
            for n=1,#validpaths do
                local fullname = joinpath(validpaths[n],name)
                data = loaddata(fullname) or ""
                if data ~= "" then
                    report("sending generic file: %s",fullname)
                    break
                end
            end
        else
            report("sending generic file: %s",fullname)
        end
    end
    if data and data ~= "" then
        client:send("HTTP/1.1 200 OK\r\n")
        client:send("Connection: close\r\n")
        client:send(f_content_length(#data))
        client:send(f_content_type(suffix and mimetypes[suffix] or "text/html"))
        client:send("Cache-Control: no-cache, no-store, must-revalidate, max-age=0\r\n")
        client:send("\r\n")
        client:send(data)
        client:send("\r\n")
    else
        report("unknown file: %s",tostring(name))
        errormessage(client,configuration,404)
    end
end

-- return os.date()

-- return { content = "crap" }

-- return function(configuration,filename)
--     return { content = filename }
-- end

local loaded = { }

function handlers.lua(client,configuration,filename,suffix,iscontent,hashed) -- filename will disappear, and become hashed.filename
    local filename = joinpath(configuration.scripts,filename)
    if not is_qualified_path(filename) then
        filename = joinpath(configuration.root,filename)
    end
    -- todo: split url in components, see l-url; rather trivial
    local result, keep = loaded[filename], false
    if result then
        report("reusing script: %s",filename)
    else
        report("locating script: %s",filename)
        if lfs.isfile(filename) then
            report("loading script: %s",filename)
            result = loadfile(filename)
            report("return type: %s",type(result))
            if result and type(result) == "function" then
             -- result() should return a table { [type=,] [length=,] content= }, function or string
                result, keep = result()
                if keep then
                    report("saving script: %s",type(result))
                    loaded[filename] = result
                end
            end
        else
            report("problematic script: %s",filename)
            errormessage(client,configuration,404)
        end
    end
    if result then
        if type(result) == "function" then
            report("running script: %s",filename)
            result = result(configuration,filename,hashed) -- second argument will become query
        end
        if result and type(result) == "string" then
            result = { content = result }
        end
        if result and type(result) == "table" then
            if result.content then
                local suffix = result.type or "text/html"
                local action = handlers[suffix] or handlers.generic
                action(client,configuration,result.content,suffix,true) -- content
            elseif result.filename then
                local suffix = filesuffix(result.filename) or "text/html"
                local action = handlers[suffix] or handlers.generic
                action(client,configuration,result.filename,suffix,false) -- filename
            else
                report("no content of filename in result")
                errormessage(client,configuration,404)
            end
        else
            report("no valid result")
            errormessage(client,configuration,500)
        end
    else
        report("no result")
        errormessage(client,configuration,404)
    end
end

handlers.luc  = handlers.lua
handlers.html = handlers.htm

local indices    = { "index.htm", "index.html" }
local portnumber = 8088

local newline    = patterns.newline
local spacer     = patterns.spacer
local whitespace = patterns.whitespace
local method     = P("GET")
                 + P("POST")
local identify   = (1-method)^0
                 * C(method)
                 * spacer^1
                 * C((1-spacer)^1)
                 * spacer^1
                 * P("HTTP/")
                 * (1-whitespace)^0
                 * C(P(1)^0)

function scripts.webserver.run(configuration)
    -- check configuration
    configuration.port = tonumber(configuration.port or os.getenv("MTX_SERVER_PORT") or portnumber) or portnumber
    if not configuration.root or not lfs.isdir(configuration.root) then
        configuration.root = os.getenv("MTX_SERVER_ROOT") or "."
    end
    -- locate root and index file in tex tree
    if not lfs.isdir(configuration.root) then
        for i=1,#indices do
            local name = indices[i]
            local root = resolvers.resolve("path:" .. name) or ""
            if root ~= "" then
                configuration.root = root
                configuration.index = configuration.index or name
                break
            end
        end
    end
    configuration.root = dir.expandname(configuration.root)
    if not configuration.index then
        for i=1,#indices do
            local name = indices[i]
            if lfs.isfile(joinpath(configuration.root,name)) then
                configuration.index = name -- we will prepend the rootpath later
                break
            end
        end
        configuration.index = configuration.index or "unknown"
    end
    if not configuration.scripts or configuration.scripts == "" then
        configuration.scripts = dir.expandname(joinpath(configuration.root or ".",configuration.scripts or "."))
    end
    -- so far for checks
    report("running at port: %s",configuration.port)
    report("document root: %s",configuration.root or resolvers.ownpath)
    report("main index file: %s",configuration.index)
    report("scripts subpath: %s",configuration.scripts)
    report("context services: http://localhost:%s/mtx-server-ctx-startup.lua",configuration.port)
    local server = assert(socket.bind("*", configuration.port))
    local script = configuration.script
    while true do -- blocking
     -- local start = gettime()
        local client = server:accept()
        client:settimeout(configuration.timeout or 60)
        local request, e = client:receive()
        if e then
            -- probably a time out
         -- errormessage(client,configuration,404)
        else
            local from = client:getpeername()
            report("request from: %s",tostring(from))
            report("request data: %s",tostring(request))
         -- local fullurl = match(request,"(GET) (.+) HTTP/.*$") or "" -- todo: more clever / post
         -- if fullurl == "" then
            local method, fullurl, body = lpegmatch(identify,request)
            if method == "" or fullurl == "" then
                report("no url")
                errormessage(client,configuration,404)
            else

                -- todo: method: POST

                fullurl = url.unescapeget(fullurl)
                report("requested url: %s",fullurl)
             -- fullurl = socket.url.unescape(fullurl) -- happens later
                local hashed = urlhashed(fullurl)
                local query = urlquery(hashed.query)
                local filename = hashed.path -- hm, not query?
                hashed.body = body
                if script then
                    filename = script
                    report("forced script: %s",filename)
                    local suffix = filesuffix(filename)
                    local action = handlers[suffix] or handlers.generic
                    if action then
                        report("performing action: %s",filename)
                        action(client,configuration,filename,suffix,false,hashed) -- filename and no content
                    else
                        report("invalid action: %s",filename)
                        errormessage(client,configuration,404)
                    end
                elseif filename then
                    local rawname = socket.url.unescape(filename)
                    filename = rawname
                    report("requested action: %s",filename or "?")
                    if find(filename,"%.%.") then
                        filename = nil -- invalid path
                    end
                    if filename == nil or filename == "" or filename == "/" then
                        filename = configuration.index
                        report("invalid filename, forcing: %s",filename)
                    end
                    local suffix = filesuffix(filename)
                    local action = handlers[suffix] or handlers.generic
                    if action then
                        report("performing action: %s",filename or "?")
                        action(client,configuration,filename,suffix,false,hashed) -- filename and no content
                    else
                        report("invalid action: %s",filename or "?")
                        errormessage(client,configuration,404)
                    end
                else
                    report("invalid request")
                    errormessage(client,configuration,404)
                end
            end
        end
        client:close()
     -- report("time spent with client: %0.03f seconds",gettime()-start)
    end
end

if environment.argument("auto") then
    local path = resolvers.findfile("mtx-server.lua") or "."
    scripts.webserver.run {
        port    = environment.argument("port"),
        root    = environment.argument("root") or dirname(path) or ".",
        scripts = environment.argument("scripts") or dirname(path) or ".",
        script  = environment.argument("script"),
    }
elseif environment.argument("start") then
    scripts.webserver.run {
        port    = environment.argument("port"),
        root    = environment.argument("root") or ".",           -- "e:/websites/www.pragma-ade.com",
        index   = environment.argument("index"),
        scripts = environment.argument("scripts"),
        script  = environment.argument("script"),
    }
elseif environment.argument("exporthelp") then
    application.export(environment.argument("exporthelp"),environment.files[1])
else
    application.help()
end

-- mtxrun --script server --start => http://localhost:8088/mtx-server-ctx-startup.lua
