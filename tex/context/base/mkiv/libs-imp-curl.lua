if not modules then modules = { } end modules ['libs-imp-curl'] = {
    version   = 1.001,
    comment   = "companion to luat-lib.mkxl",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- c:/data/develop/tex-context/tex/texmf-win64/bin/lib/luametatex/lua/copies/curl/libcurl.dll

local libname = "curl"
local libfile = "libcurl"

local curllib = resolvers.libraries.validoptional(libname)

if not curllib then return end

-- We're good, so we continue.

local next, type = next, type
local lower, gsub = string.lower, string.gsub

local mapping = {
    ["acceptencoding"]          = 102,
    ["accepttimeoutms"]         = 212,
    ["addressscope"]            = 171,
    ["append"]                  =  50,
    ["autoreferer"]             =  58,
    ["buffersize"]              =  98,
    ["cainfo"]                  =  65,
    ["capath"]                  =  97,
    ["certinfo"]                = 172,
 -- ["chunkbgnfunction"]        = 198,
    ["chunkdata"]               = 201,
 -- ["chunkendfunction"]        = 199,
    ["closepolicy"]             =  72,
    ["closesocketdata"]         = 209,
 -- ["closesocketfunction"]     = 208,
    ["connectonly"]             = 141,
    ["connecttimeout"]          =  78,
    ["connecttimeoutms"]        = 156,
 -- ["convfromnetworkfunction"] = 142,
 -- ["convfromutf8function"]    = 144,
 -- ["convtonetworkfunction"]   = 143,
    ["cookie"]                  =  22,
    ["cookiefile"]              =  31,
    ["cookiejar"]               =  82,
    ["cookielist"]              = 135,
    ["cookiesessionv"]          =  96,
    ["copypostfields"]          = 165,
    ["crlf"]                    =  27,
    ["crlfile"]                 = 169,
    ["customrequest"]           =  36,
    ["debugdata"]               =  95,
 -- ["debugfunction"]           =  94,
    ["dirlistonly"]             =  48,
    ["dnscachetimeout"]         =  92,
    ["dnsinterface"]            = 221,
    ["dnslocalip4"]             = 222,
    ["dnslocalip6"]             = 223,
    ["dnsservers"]              = 211,
    ["dnsuseglobalcache"]       =  91,
    ["egdsocket"]               =  77,
    ["errorbuffer"]             =  10,
    ["expect100timeoutms"]      = 227,
    ["failonerror"]             =  45,
    ["file"]                    =   1,
    ["filetime"]                =  69,
    ["fnmatchdata"]             = 202,
 -- ["fnmatchfunction"]         = 200,
    ["followlocation"]          =  52,
    ["forbidreuse"]             =  75,
    ["freshconnect"]            =  74,
    ["ftpaccount"]              = 134,
    ["ftpalternativetouser"]    = 147,
    ["ftpcreatemissingdirs"]    = 110,
    ["ftpfilemethod"]           = 138,
    ["ftpresponsetimeout"]      = 112,
    ["ftpskippasvip"]           = 137,
    ["ftpsslccc"]               = 154,
    ["ftpuseeprt"]              = 106,
    ["ftpuseepsv"]              =  85,
    ["ftpusepret"]              = 188,
    ["ftpport"]                 =  17,
    ["ftpsslauth"]              = 129,
    ["gssapidelegation"]        = 210,
    ["header"]                  =  42,
    ["headerdata"]              =  29,
 -- ["headerfunction"]          =  79,
    ["http200aliases"]          = 104,
    ["httpcontentdecoding"]     = 158,
    ["httptransferdecoding"]    = 157,
    ["httpversion"]             =  84,
    ["httpauth"]                = 107,
    ["httpget"]                 =  80,
    ["httpheader"]              =  23,
    ["httppost"]                =  24,
    ["httpproxytunnel"]         =  61,
    ["ignorecontentlength"]     = 136,
    ["infile"]                  =   9,
    ["infilesize"]              =  14,
    ["infilesizelarge"]         = 115,
    ["interface"]               =  62,
    ["interleavedata"]          = 195,
 -- ["interleavefunction"]      = 196,
    ["ioctldata"]               = 131,
 -- ["ioctlfunction"]           = 130,
    ["ipresolve"]               = 113,
    ["issuercert"]              = 170,
    ["keypasswd"]               =  26,
    ["krblevel"]                =  63,
    ["localport"]               = 139,
    ["localportrange"]          = 140,
    ["loginoptions"]            = 224,
    ["lowspeedlimit"]           =  19,
    ["lowspeedtime"]            =  20,
    ["mailauth"]                = 217,
    ["mailfrom"]                = 186,
    ["mailrcpt"]                = 187,
    ["maxrecvspeedlarge"]       = 146,
    ["maxsendspeedlarge"]       = 145,
    ["maxconnects"]             =  71,
    ["maxfilesize"]             = 114,
    ["maxfilesizelarge"]        = 117,
    ["maxredirs"]               =  68,
    ["netrc"]                   =  51,
    ["netrcfile"]               = 118,
    ["newdirectoryperms"]       = 160,
    ["newfileperms"]            = 159,
    ["nobody"]                  =  44,
    ["noprogress"]              =  43,
    ["noproxy"]                 = 177,
    ["nosignal"]                =  99,
    ["opensocketdata"]          = 164,
 -- ["opensocketfunction"]      = 163,
    ["password"]                = 174,
    ["port"]                    =   3,
    ["post"]                    =  47,
 -- ["postfields"]              =  15,
 -- ["postfieldsize"]           =  60,
 -- ["postfieldsizelarge"]      = 120,
    ["postquote"]               =  39,
    ["postredir"]               = 161,
    ["prequote"]                =  93,
    ["private"]                 = 103,
    ["progressdata"]            =  57,
 -- ["progressfunction"]        =  56,
    ["protocols"]               = 181,
    ["proxy"]                   =   4,
    ["proxytransfermode"]       = 166,
    ["proxyauth"]               = 111,
    ["proxypassword"]           = 176,
    ["proxyport"]               =  59,
    ["proxytype"]               = 101,
    ["proxyusername"]           = 175,
    ["proxyuserpwd"]            =   6,
    ["put"]                     =  54,
    ["quote"]                   =  28,
    ["randomfile"]              =  76,
    ["range"]                   =   7,
    ["readdata"]                =   9,
 -- ["readfunction"]            =  12,
    ["redirprotocols"]          = 182,
    ["referer"]                 =  16,
    ["resolve"]                 = 203,
    ["resumefrom"]              =  21,
    ["resumefromlarge"]         = 116,
    ["rtspclientcseq"]          = 193,
    ["rtsprequest"]             = 189,
    ["rtspservercseq"]          = 194,
    ["rtspsessionid"]           = 190,
    ["rtspstreamuri"]           = 191,
    ["rtsptransport"]           = 192,
    ["rtspheader"]              =  23,
    ["saslir"]                  = 218,
    ["seekdata"]                = 168,
 -- ["seekfunction"]            = 167,
    ["serverresponsetimeout"]   = 112,
    ["share"]                   = 100,
    ["sockoptdata"]             = 149,
 -- ["sockoptfunction"]         = 148,
    ["socks5gssapinec"]         = 180,
    ["socks5gssapiservice"]     = 179,
    ["sshauthtypes"]            = 151,
    ["sshhostpublickeymd5"]     = 162,
    ["sshkeydata"]              = 185,
 -- ["sshkeyfunction"]          = 184,
    ["sshknownhosts"]           = 183,
    ["sshprivatekeyfile"]       = 153,
    ["sshpublickeyfile"]        = 152,
    ["sslcipherlist"]           =  83,
    ["sslctxdata"]              = 109,
 -- ["sslctxfunction"]          = 108,
    ["sslenablealpn"]           = 226,
    ["sslenablenpn"]            = 225,
    ["ssloptions"]              = 216,
    ["sslsessionidcache"]       = 150,
    ["sslverifyhost"]           =  81,
    ["sslverifypeer"]           =  64,
    ["sslcert"]                 =  25,
    ["sslcerttype"]             =  86,
    ["sslengine"]               =  89,
    ["sslenginedefault"]        =  90,
    ["sslkey"]                  =  87,
    ["sslkeytype"]              =  88,
    ["sslversion"]              =  32,
    ["stderr"]                  =  37,
    ["tcpkeepalive"]            = 213,
    ["tcpkeepidle"]             = 214,
    ["tcpkeepintvl"]            = 215,
    ["tcpnodelay"]              = 121,
    ["telnetoptions"]           =  70,
    ["tftpblksize"]             = 178,
    ["timecondition"]           =  33,
    ["timeout"]                 =  13,
    ["timeoutms"]               = 155,
    ["timevalue"]               =  34,
    ["tlsauthpassword"]         = 205,
    ["tlsauthtype"]             = 206,
    ["tlsauthusername"]         = 204,
    ["transferencoding"]        = 207,
    ["transfertext"]            =  53,
    ["unrestrictedauth"]        = 105,
    ["upload"]                  =  46,
    ["url"]                     =   2,
    ["usessl"]                  = 119,
    ["useragent"]               =  18,
    ["username"]                = 173,
    ["userpwd"]                 =   5,
    ["verbose"]                 =  41,
    ["wildcardmatch"]           = 197,
    ["writedata"]               =   1,
 -- ["writefunction"]           =  11,
    ["writeheader"]             =  29,
    ["writeinfo"]               =  40,
    ["xferinfodata"]            =  57,
 -- ["xferinfofunction"]        = 219,
    ["xoauth2bearer"]           = 220,
}

table.setmetatableindex(mapping,function(t,k)
    local s = gsub(lower(k),"[^a-z0-9]","")
    local v = rawget(t,s) or false
    t[k] = v
    return v
end)

local curl_fetch      = curllib.fetch
local curl_escape     = curllib.escape
local curl_unescape   = curllib.unescape
local curl_getversion = curllib.getversion

local report          = logs.reporter(libname)

local function okay()
    if resolvers.libraries.optionalloaded(libname,libfile) then
        okay = function() return true end
    else
        okay = function() return false end
    end
    return okay()
end

local function fetch(options)
    if okay() then
        local t = type(options)
        if t == "table" then
            local o = { }
            for name, value in next, options do
                local index = mapping[name]
                if index then
                    o[index] = value
                end
            end
            return curl_fetch(o)
        elseif t == "string" then
            return curl_fetch { [mapping.url] = options }
        else
            report("invalid argument")
        end
    end
end

local curl = {
    getversion = function ()  return okay() and curl_getversion()  end,
    escape     = function (s) return okay() and curl_escape    (s) end,
    unescape   = function (s) return okay() and curl_unescape  (s) end,
    fetch      = fetch,
}

-- inspect(curl.fetch("http://www.pragma-ade.com/index.html"))
-- inspect(curl.fetch { url = "http://www.pragma-ade.com/index.html" })

package.loaded[libname] = curl

return curl
