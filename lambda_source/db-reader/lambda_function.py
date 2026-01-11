import oracledb, json, os

pool = None

def get_connection():
    global pool
    wallet_path = os.path.join(os.environ.get('LAMBDA_TASK_ROOT', os.getcwd()), 'wallet')
    
    if pool is None:
        print("Connection Pool oluşturuluyor...") 
        pool = oracledb.create_pool(
            user=os.environ['DB_USER'], 
            password=os.environ['DB_PASSWORD'], 
            dsn=os.environ['DB_DSN'], 
            config_dir=wallet_path, 
            wallet_location=wallet_path, 
            wallet_password=os.environ['WALLET_PASSWORD'], 
            min=1, 
            max=2
        )
    return pool.acquire()

def lambda_handler(event, context):
    conn = None
    cursor = None 
    try:
        conn = get_connection()
        cursor = conn.cursor()
        
        sql = """SELECT magaza_adi, fis_tarihi, fis_saati, toplam_tutar, urun_listesi 
                 FROM market_fisleri 
                 ORDER BY fis_tarihi DESC, fis_saati DESC 
                 FETCH NEXT 20 ROWS ONLY""" 
        
        cursor.execute(sql)
        columns = [col[0].lower() for col in cursor.description]
        rows = cursor.fetchall()
        
        result = []
        for row in rows:
            temp_row = list(row)
            if hasattr(temp_row[4], "read"): 
                temp_row[4] = temp_row[4].read()
            
            row_dict = dict(zip(columns, temp_row))
            
            if row_dict['fis_tarihi']: 
                row_dict['fis_tarihi'] = str(row_dict['fis_tarihi'])
            
            try: 
                row_dict['urun_listesi'] = json.loads(row_dict['urun_listesi'])
            except: 
                pass 
                
            result.append(row_dict)

        return {
            "statusCode": 200,
            "headers": {
                "Access-Control-Allow-Origin": "*",
                "Access-Control-Allow-Headers": "Content-Type",
                "Access-Control-Allow-Methods": "OPTIONS,POST,GET"
            },
            "body": json.dumps(result, ensure_ascii=False)
        }
    except Exception as e:
        print(f"DB Error: {e}")
        return {"statusCode": 500, "body": json.dumps({"error": str(e)})}
    finally:
        if cursor: 
            try: cursor.close()
            except: pass
        if conn: 
            try: pool.release(conn)
            except: pass