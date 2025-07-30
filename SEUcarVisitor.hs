#!/bin/bash

set -e

# 传入参数，日期偏移天数，默认0（今天）
day_offset=${1:-0}

#把代码中所有“请输入手机号”替换为申请人的手机号

# 替换为你的 Cookie,JSESSIONID等
COOKIE='INGRESSCOOKIE=xxxxxxxxxxxxxxx; JSESSIONID=xxxxxxxxxxxxxx; 8bf5c9df-5c80-401b-a23a-d3fa6f91a918=xxxxxxxxxx; loginname=请输入手机号'

# 你的设备，一般不动也行
USER_AGENT='Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/138.0.0.0 Safari/537.36 Edg/138.0.0.0'

#填入你的申请页网址，就是手机验证码登录完之后的页面
START_URL='xxxxxxxxxx'

echo "访问 start 页面，初始化会话..."
curl -s "$START_URL" -H "Cookie: $COOKIE" -H "User-Agent: $USER_AGENT" > /dev/null

# 计算目标时间戳（UTC）
target_ts=$(( $(date -u +%s) + day_offset*86400 ))
target_year=$(date -u -d "@$target_ts" +%Y)
target_month=$(date -u -d "@$target_ts" +%-m)
target_day=$(date -u -d "@$target_ts" +%-d)

target_day0_ts=$(date -u -d "$(date -u -d "@$target_ts" +%Y-%m-%d) 00:00:00" +%s)

echo "目标日期：$target_year-$target_month-$target_day"
echo "目标日期当天0点时间戳：$target_day0_ts"

# 当前unix时间戳
NOW_TS=$(date +%s)

# 当前年月日
NOW_YEAR=$(date +%Y)
NOW_MONTH=$(date +%-m)    # 1-12
NOW_DAY=$(date +%-d)      # 1-31

# _VAR_TODAY 是当天零点时间戳，取当天0点
TODAY_TS=$(date -d "$(date +%Y-%m-%d) 00:00:00" +%s)

# formData 用单引号包裹，内部换行是真换行
FORMDATA='{
  "fieldHYYFZ1":"显示",
  "fieldHYYFZ2":"",
  "fieldQR":true,
  "_VAR_ACTION_INDEP_ORGANIZES_Codes":"IT
243015",
  "_VAR_ACTION_REALNAME":"System",
  "_VAR_ACTION_ORGANIZE":"IT",
  "_VAR_ACTION_INDEP_ORGANIZE":"IT",
  "_VAR_ACTION_INDEP_ORGANIZE_Name":"IT",
  "_VAR_ACTION_ORGANIZE_Name":"IT",
  "_VAR_OWNER_ORGANIZES_Codes":"IT
243015",
  "_VAR_ADDR":"112.87.194.127",
  "_VAR_OWNER_ORGANIZES_Names":"IT
网络与信息中心",
  "_VAR_URL":"'"$START_URL"'",
  "_VAR_URL_Name":"'"$START_URL"'",
  "_VAR_URL_Attr":"{\"sig\":\"bd12f0a41c7a9b8a2a2d0cbd48b138dc\",\"ts\":\"1767024000\",\"uid\":\"0f1fb840-aa02-11ea-b752-005056bd7aba\",\"lxfs\":\"请输入手机号\"}",
  "_VAR_RELEASE":"true",
  "_VAR_TODAY":"'"$TODAY_TS"'",
  "_VAR_NOW_MONTH":"'"$NOW_MONTH"'",
  "_VAR_ACTION_ACCOUNT":"System",
  "_VAR_ACTION_INDEP_ORGANIZES_Names":"IT
网络与信息中心",
  "_VAR_OWNER_ACCOUNT":"System",
  "_VAR_ACTION_ORGANIZES_Names":"IT
网络与信息中心",
  "_VAR_NOW_DAY":"'"$NOW_DAY"'",
  "_VAR_OWNER_REALNAME":"System",
  "_VAR_NOW":"'"$NOW_TS"'",
  "_VAR_ENTRY_NUMBER":"-1",
  "_VAR_POSITIONS":"IT:FACULTY
IT:ADMIN
243015:FACULTY",
  "_VAR_ACTION_ORGANIZES_Codes":"IT
243015",
  "_VAR_NOW_YEAR":"'"$NOW_YEAR"'",
  "_VAR_ENTRY_NAME":"",
  "_VAR_ENTRY_TAGS":""
}'


echo "调用 start 接口..."

start_response=$(curl -s 'https://infoplus.seu.edu.cn/infoplus/interface/start' \
  -H "Accept: application/json, text/javascript, */*; q=0.01" \
  -H "Content-Type: application/x-www-form-urlencoded; charset=UTF-8" \
  -H "Cookie: $COOKIE" \
  -H "Referer: $START_URL" \
  -H "User-Agent: $USER_AGENT" \
  --data-urlencode "idc=XWJXSQ" \
  --data-urlencode "release=true" \
  --data-urlencode "csrfToken=" \
  --data-urlencode "formData=$FORMDATA" \
  --data-urlencode "lang=zh" )

echo "start接口返回内容："
echo "$start_response" | jq .

# 判断是否成功
errno=$(echo "$start_response" | jq -r '.errno')
if [ "$errno" != "0" ]; then
  echo "start接口调用失败，退出。"
  exit 1
fi

# 从start返回解析stepId
STEP_ID=$(echo "$start_response" | jq -r '.entities[0]' | sed -E 's#.*/form/([0-9]+)/render#\1#')
if [ -z "$STEP_ID" ]; then
  echo "未能解析到stepId，退出。"
  exit 1
fi
echo "解析到 stepId=$STEP_ID"

# 读取raw.json，并替换时间相关字段
if [ ! -f raw.json ]; then
  echo "raw.json 文件不存在，请准备好表单JSON数据。"
  exit 1
fi

# 用 sed 替换 _VAR_STEP_NUMBER
sed -i "s/\"_VAR_STEP_NUMBER\":\"[0-9]\+\"/\"_VAR_STEP_NUMBER\":\"$STEP_ID\"/" raw.json

# 用 sed 替换 _VAR_URL 中的步骤号
sed -i "s|https://infoplus.seu.edu.cn/infoplus/form/[0-9]\+/render|https://infoplus.seu.edu.cn/infoplus/form/$STEP_ID/render|" raw.json

# 读取 raw.json 并用 jq 替换关键字段
updated_json=$(jq \
  --argjson now_ts "$NOW_TS" \
  --argjson target_day0_ts "$target_day0_ts" \
  --arg year "$target_year" \
  --arg month "$target_month" \
  --arg day "$target_day" \
  '.["_VAR_TODAY"] = $target_day0_ts
  | .["_VAR_NOW_YEAR"] = ($year | tonumber)
  | .["_VAR_NOW_MONTH"] = ($month | tonumber)
  | .["_VAR_NOW_DAY"] = ($day | tonumber)
  | .["_VAR_NOW"] = $now_ts
  | if has("fieldSQSJ") then .fieldSQSJ = $now_ts else . end
  | if has("fieldSJFrom") then .fieldSJFrom = $target_day0_ts else . end
  | if has("fieldSJFrom1") then .fieldSJFrom1 = $target_day0_ts else . end
  ' raw.json)

# urlencode函数
urlencode() {
  python3 -c "import sys, urllib.parse; print(urllib.parse.quote(sys.stdin.read().strip()))"
}

encoded_formData=$(echo "$updated_json" | urlencode)

echo "调用 doAction 接口提交..."

doaction_response=$(curl -s 'https://infoplus.seu.edu.cn/infoplus/interface/doAction' \
  -H 'Accept: application/json, text/javascript, */*; q=0.01' \
  -H 'Accept-Language: zh-CN,zh;q=0.9,en;q=0.8,en-GB;q=0.7,en-US;q=0.6' \
  -H 'Connection: keep-alive' \
  -H 'Content-Type: application/x-www-form-urlencoded; charset=UTF-8' \
  -H "Cookie: $COOKIE" \
  -H 'Origin: https://infoplus.seu.edu.cn' \
  -H "Referer: https://infoplus.seu.edu.cn/infoplus/form/${STEP_ID}/render?uid=0f1fb840-aa02-11ea-b752-005056bd7aba" \
  -H "User-Agent: $USER_AGENT" \
  -H 'X-Requested-With: XMLHttpRequest' \
  --data-raw "actionId=19&formData=$encoded_formData&remark=&rand=$(awk 'BEGIN{srand();print rand()}')&nextUsers={}&stepId=${STEP_ID}&timestamp=$target_ts&boundFields=fieldEWM,fieldFZDW,fieldFZ2,fieldFZ3,fieldFZ4,fieldHIDDEN,fieldSFXSJZ,fieldGZSHR,fieldXYYSHYJ,fieldCNFZ,fieldSJFrom,fieldJC,fieldWCE,fieldDSSHR,fieldJDDW,fieldSJFrom1,fieldXSGYSHR,fieldLDSHR,fieldGZSHRQ,fieldYC,fieldQR,fieldJXZ,fieldRXSJFZ,fieldQWXQ3,fieldLXFS,fieldQWXQ2,fieldQWXQ1,fieldFDYXM,fieldJXSQLX,fieldBMED,fieldFZSTATE,fieldSQSJ,fieldCN,fieldSQLXFZ,fieldJDRFZ,fieldTS,fieldFDYSHR,fieldSqYx,fieldFDYSHSJ,fieldBMSHSHTY,fieldJDRYXM,fieldRXSJFZ2,fieldSbsj,fieldSqRsbh,fieldSFZGJ,fieldMQJCRY,fieldBZ,fieldJZRXSY,fieldGLDD,fieldTimeFZ,fieldSqBgdh,fieldSqrDqwz,fieldFDYLXFS,fieldHZH,fieldYSP,fieldLDSHSJ,fieldDW,fieldFDYSHYJ,fieldXYYSHTY,fieldSFJD,fieldXZJDR,fieldJDRYLXDH,fieldXSSSQ,fieldXSSZYX,fieldURL,fieldXSGYSH,fieldSqrXm,fieldZYSM,fieldJDR,fieldXSGYSHRQ,fieldXM,fieldLSH,fieldSJFZ2,fieldH1,fieldSJFZ1,fieldSJFZ4,fieldSJFZ3,fieldH5,fieldH2,fieldH3,fieldBMCSSFTY,fieldJDRSH,fieldSFZH,fieldSJFZ6,fieldXBSHSFTY,fieldSJFZ5,fieldJDRSHRQ,fieldSJFZ8,fieldSJFZ7,fieldLDSHYJ,fieldCPH,fieldGZSH,fieldXYYSHRQ,fieldFZ,fieldJDRSHR,fieldHYYFZ2,fieldJDDW1,fieldHYYFZ1,fieldXYYSHR,fieldCHTS&csrfToken=&lang=zh")


echo "doAction接口返回内容："
echo "$doaction_response" | jq .
