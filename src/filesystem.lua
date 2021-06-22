-- files can only be opened/saved by dialogue prompt.
-- no random access to disk is permitted by the environment.
function fs_requires_user_access()
  return g_is_web
end

if fs_requires_user_access() then
  -- js api
  JS.callJS(JS.stringFunc([[
    jsDownloadToFile = (content, filename, contentType) => {
      const a = document.createElement('a');
      const file = new Blob([content], {type: contentType});
      
      a.href= URL.createObjectURL(file);
      a.download = filename;
      a.click();
    
      URL.revokeObjectURL(a.href);
    };
  ]]))

  local function sanitize_string_for_js(s)
    assert(type(s) == "string")
    return s:gsub([["]], [[\"]]):gsub("\n", [[\n]])
  end

  function fs_js_save(content, filename, contentType)
    if type(content) ~= "table" then
      content = {content}
    end
    local s = "const content = ["
    for i, v in ipairs(content) do
      if i ~= 1 then
        s = s .. ","
      end
      if type(v) == "string" then
        s = s .. '"' .. sanitize_string_for_js(v) .. '"'
      elseif type(s) == "number" then
        assert(v == math.floor(v) and v >= -128 and v < 256)
        s = s .. "new Int8Array([" .. tostring(v) .. "])"
      else
        assert(false, "can only write bytes and strings")
      end
    end
    s = s .. "];\n jsDownloadToFile(content, \"" .. sanitize_string_for_js(filename) .. "\", \"" .. sanitize_string_for_js(contentType) .. "\")"

    JS.callJS(JS.stringFunc(s))
  end
end

-- either saves or prompts a save
function fs_save(content, filename)
  assert(filename and type(filename) == "string" and #filename > 0)
  if g_is_web then
    fs_js_save(content, filename or "save.txt", "text/plain")
  else
    love.filesystem.write(filename, content)
  end
end