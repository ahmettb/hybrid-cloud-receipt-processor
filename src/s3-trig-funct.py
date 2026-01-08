import boto3, json, urllib.parse, os, oracledb, re

s3 = boto3.client('s3')
textract = boto3.client('textract')
bedrock_runtime = boto3.client('bedrock-runtime', region_name='us-east-1')

def clean_json_response(raw_text):
    match = re.search(r'\{.*\}', raw_text, re.DOTALL)
    return match.group(0) if match else raw_text.strip()

def lambda_handler(event, context):
    try:
        bucket = event['Records'][0]['s3']['bucket']['name']
        key = urllib.parse.unquote_plus(event['Records'][0]['s3']['object']['key'])
        
        text_resp = textract.detect_document_text(Document={'S3Object':{'Bucket':bucket,'Name':key}})
        full_text = " ".join([b["Text"] for b in text_resp["Blocks"] if b["BlockType"]=="LINE"])

        prompt = f"Human: Market fişini analiz et ve SADECE JSON dön. Şema: {{magaza_adi, fis_tarihi(YYYY-MM-DD), fis_saati, toplam_tutar(sayı), kdv_tutari(sayı), odeme_tipi, urun_listesi:[{{urun, fiyat}}]}} Metin: {full_text} Assistant: {{"
        
        payload = {
            "anthropic_version": "bedrock-2023-05-31",
            "max_tokens": 1000,
            "messages": [{"role": "user", "content": [{"type": "text", "text": prompt}]}]
        }
        
        resp = bedrock_runtime.invoke_model(modelId="anthropic.claude-3-haiku-20240307-v1:0", body=json.dumps(payload))
        ai_text = "{" + json.loads(resp.get('body').read())['content'][0]['text'] 
        data = json.loads(clean_json_response(ai_text))

        wallet_path = os.path.join(os.getcwd(), 'wallet')
        conn = oracledb.connect(user=os.environ['DB_USER'], password=os.environ['DB_PASSWORD'], dsn=os.environ['DB_DSN'], config_dir=wallet_path, wallet_location=wallet_path, wallet_password=os.environ['WALLET_PASSWORD'])
        
        cursor = conn.cursor()
        sql = "INSERT INTO market_fisleri (magaza_adi, fis_tarihi, fis_saati, toplam_tutar, kdv_tutari, odeme_tipi, urun_listesi) VALUES (:1, TO_DATE(:2, 'YYYY-MM-DD'), :3, :4, :5, :6, :7)"
        cursor.execute(sql, [data.get('magaza_adi'), data.get('fis_tarihi','2000-01-01'), data.get('fis_saati'), float(data.get('toplam_tutar',0)), float(data.get('kdv_tutari',0)), data.get('odeme_tipi'), json.dumps(data.get('urun_listesi'))])
        conn.commit()
        
        return {'statusCode': 200, 'body': 'Başarılı'}
    except Exception as e:
        print(f"Hata: {e}")
        return {'statusCode': 500, 'body': str(e)}