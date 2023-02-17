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

local update_sql = "update test set ch = '"..ngx.var.arg_name.."' where id =" .. ngx.var.arg_id
res, err, errno, sqlstate = db:query(update_sql)
if not res then
   ngx.say("update error : ", err, " , errno : ", errno, " , sqlstate : ", sqlstate)
   return close_db(db)
end

ngx.say("update rows : ", res.affected_rows, "<br/>")

ngx.say("ok")
close_db(db)