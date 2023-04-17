local mysql = require "resty.mysql"

local function get_client_ip()
    return ngx.var.remote_addr or "unknown"
end

local function get_user_agent()
    return ngx.var.http_user_agent or "unknown"
end

local function get_page_url()
    return ngx.var.http_referer or "unknown"
end

local function display_image(image_path)
    local file = io.open(image_path, "rb")
    if not file then
        ngx.log(ngx.ERR, "failed to open image file: ", image_path)
        ngx.exit(ngx.HTTP_NOT_FOUND)
        return
    end

    local content = file:read("*all")
    file:close()

    ngx.header.content_type = "image/jpeg"
    ngx.header.content_length = #content
    ngx.print(content)
end

local function update_or_insert(ip, user_agent, page_url)
    local db, err = mysql:new()
    if not db then
        ngx.log(ngx.ERR, "failed to instantiate mysql: ", err)
        return
    end

    local ok, err, errno, sqlstate = db:connect {
        host = "db",
        port = 3306,
        database = "banner_db",
        user = "root",
        password = "pass",
        charset = "utf8",
        max_packet_size = 1024 * 1024,
    }

    if not ok then
        ngx.log(ngx.ERR, "failed to connect: ", err, ": ", errno, " ", sqlstate)
        return
    end

    local sql = "INSERT INTO views (ip_address, user_agent, page_url, view_date, views_count) " ..
            "VALUES (" .. ngx.quote_sql_str(ip) .. ", " .. ngx.quote_sql_str(user_agent) .. ", " .. ngx.quote_sql_str(page_url) .. ", NOW(), 1) " ..
            "ON DUPLICATE KEY UPDATE views_count = views_count + 1"

    local res, err, errno, sqlstate = db:query(sql)

    if err then
        ngx.log(ngx.ERR, "failed to execute query: ", err, ": ", errno, " ", sqlstate)
    end

    db:set_keepalive(10000, 10)
end

-- Call update_or_insert
local client_ip = get_client_ip()
local user_agent = get_user_agent()
local page_url = get_page_url()
update_or_insert(client_ip, user_agent, page_url)

-- Display image
local image_path = "banner.png"
display_image(image_path)