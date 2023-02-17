local function close_db(db)
    if not db then
        return
    end
    db:close()
end

local mysql = require("resty.mysql")

local db, err = mysql:new()
if not db then
    ngx.say("new mysql error : ", err)
    return
end

db:set_timeout(1000)

local props = {
    host = "127.0.0.1",
    port = 3306,
    database = "mysql",
    user = "root",
    password = "123"
}

local res, err, errno, sqlstate = db:connect(props)

if not res then
   ngx.say("connect to mysql error : ", err, " , errno : ", errno, " , sqlstate : ", sqlstate)
   return close_db(db)
end

local delete_sql = "delete from test where ch='"..ngx.var.arg_ch.."'"
res, err, errno, sqlstate = db:query(delete_sql)
if not res then
   ngx.say("delete error : ", err, " , errno : ", errno, " , sqlstate : ", sqlstate)
   return close_db(db)
end

ngx.say("ok")
close_db(db)