import os
from pathlib import Path

import pandas as pd
import numpy as np
import psycopg2
from psycopg2.extras import execute_values
from sklearn.metrics.pairwise import cosine_similarity
from dotenv import load_dotenv

# .env を読み込んでから DATABASE_URL を解決（未設定ならローカル Supabase にフォールバック）
load_dotenv()
BASE_DIR = Path(__file__).resolve().parent
DB_URL = os.environ.get("DATABASE_URL", "postgresql://postgres:postgres@localhost:54322/postgres")

def get_connection():
    return psycopg2.connect(DB_URL, connect_timeout=10)

def load_external_stores(conn):
    print("--- Loading seed_stores ---")
    df = pd.read_csv(BASE_DIR / 'venue_master.csv', encoding='utf-8')
    
    # カラム名マッピング (Venue ID -> id, 等)
    # csv columns: Venue ID,Name,Category,Latitude,Longitude,Budget,Atmosphere,Taste,Cost_Performance,Service,Access
    
    # NULL値を None に変換
    df = df.where(pd.notnull(df), None)
    
    insert_query = """
    INSERT INTO seed_stores (id, name, category, lat, lng, budget, atmosphere, taste, cost_performance, service, access)
    VALUES %s
    ON CONFLICT (id) DO NOTHING;
    """
    
    data = []
    for _, row in df.iterrows():
        data.append((
            str(row['Venue ID']), str(row['Name']), str(row['Category']),
            float(row['Latitude']), float(row['Longitude']),
            int(row['Budget']) if pd.notna(row['Budget']) and str(row['Budget']).isdigit() else None,
            int(row['Atmosphere']) if pd.notna(row['Atmosphere']) and str(row['Atmosphere']).isdigit() else None,
            int(row['Taste']) if pd.notna(row['Taste']) and str(row['Taste']).isdigit() else None,
            int(row['Cost_Performance']) if pd.notna(row['Cost_Performance']) and str(row['Cost_Performance']).isdigit() else None,
            int(row['Service']) if pd.notna(row['Service']) and str(row['Service']).isdigit() else None,
            int(row['Access']) if pd.notna(row['Access']) and str(row['Access']).isdigit() else None
        ))
    
    cursor = conn.cursor()
    execute_values(cursor, insert_query, data, page_size=1000)
    conn.commit()
    print(f"Inserted {len(data)} venues.")

def load_external_checkins(conn):
    print("--- Loading seed_checkins ---")
    df = pd.read_csv(BASE_DIR / 'real_osaka_checkins.csv', encoding='utf-8')
    
    # csv columns: User ID,Venue ID,Venue Category Name,UTC Time,Time Offset
    
    # 日時のパース
    # フォーマット: Tue Apr 03 21:39:07 +0000 2012
    # pandasのto_datetimeで一括パース
    print("Parsing dates...")
    df['checked_in_at'] = pd.to_datetime(df['UTC Time'], format='%a %b %d %H:%M:%S %z %Y', errors='coerce')
    
    # 不要な行やエラーになった行を除外
    df = df.dropna(subset=['checked_in_at', 'User ID', 'Venue ID', 'Venue Category Name'])
    
    # --- [OPTION] 自社データの統合（将来用） ---
    # 自社アプリの実際のチェックインデータも親和性計算に含めたい場合は、以下のコメントを外してください。
    """
    print("Merging internal checkins from database...")
    df_internal = pd.read_sql("SELECT user_id, venue_id, category_name, checked_in_at FROM checkins", conn)
    # カラム名を外部データ側のフォーマットに合わせる
    df_internal = df_internal.rename(columns={
        'user_id': 'User ID', 
        'venue_id': 'Venue ID', 
        'category_name': 'Venue Category Name'
    })
    # 外部データと自社データを結合
    df = pd.concat([df, df_internal], ignore_index=True)
    """
    # ----------------------------------------
    
    insert_query = """
    INSERT INTO seed_checkins (user_id, venue_id, category_name, checked_in_at, time_offset)
    VALUES %s;
    """
    
    data = []
    for _, row in df.iterrows():
        data.append((
            int(row['User ID']),
            str(row['Venue ID']),
            str(row['Venue Category Name']),
            row['checked_in_at'].to_pydatetime(),
            int(row['Time Offset']) if pd.notna(row['Time Offset']) else 0
        ))
    
    cursor = conn.cursor()
    # 既存データを削除してから投入
    cursor.execute("TRUNCATE TABLE seed_checkins;")
    execute_values(cursor, insert_query, data, page_size=5000)
    conn.commit()
    print(f"Inserted {len(data)} checkins.")
    return df

def calculate_and_load_category_affinity(conn, df_checkins):
    print("--- Calculating category_affinity ---")
    
    # User-Category のピボットテーブル（ユーザーが各カテゴリに何回チェックインしたか）
    print("Creating User-Category Matrix...")
    user_cat_matrix = df_checkins.pivot_table(
        index='User ID', 
        columns='Venue Category Name', 
        aggfunc='size', 
        fill_value=0
    )
    
    # コサイン類似度を計算（カテゴリ間の類似度なので、転置して計算）
    print("Calculating Cosine Similarity...")
    cat_sim = cosine_similarity(user_cat_matrix.T)
    categories = user_cat_matrix.columns.tolist()
    
    insert_query = """
    INSERT INTO category_affinity (category_a, category_b, score)
    VALUES %s
    ON CONFLICT (category_a, category_b) 
    DO UPDATE SET score = EXCLUDED.score, updated_at = now();
    """
    
    data = []
    # しきい値（これ以下の類似度はノイズとして無視する）
    THRESHOLD = 0.05
    
    for i in range(len(categories)):
        for j in range(len(categories)):
            if i != j:  # 同じカテゴリ同士は保存しない
                score = float(cat_sim[i][j])
                if score >= THRESHOLD:
                    data.append((
                        categories[i],
                        categories[j],
                        score
                    ))
    
    cursor = conn.cursor()
    execute_values(cursor, insert_query, data, page_size=5000)
    conn.commit()
    print(f"Inserted/Updated {len(data)} category affinity pairs.")

def load_stores_from_external(conn):
    print("--- Loading subset of external stores into stores table (30 items grid-dispersed) ---")
    
    # 1. データベースからシード駐輪場 (parking_lots) の位置情報を取得
    cursor = conn.cursor()
    cursor.execute("SELECT id, name, lat, lng FROM parking_lots;")
    parking_lots = cursor.fetchall()
    if not parking_lots:
        print("No parking lots found in database. Please run seed first.")
        return
    
    print(f"Found {len(parking_lots)} parking lots to use as geographic seeds.")
    
    # 2. venue_master.csv を読み込む
    df = pd.read_csv(BASE_DIR / 'venue_master.csv', encoding='utf-8')
    
    # 対象カテゴリの定義
    target_categories = [
        'Coffee Shop', 'Café', 'Café', 'Caf', 'Bakery', 'Dessert Shop', 
        'Italian Restaurant', 'Chinese Restaurant', 'Japanese Restaurant', 
        'Bar', 'Sake Bar', 'Sandwich Place', 'Burger Joint', 
        'Ramen /  Noodle House', 'Ramen / Noodle House', 'Restaurant', 'Diner', 
        'BBQ Joint', 'Steakhouse', 'Pizza Place', 'French Restaurant', 
        'Indian Restaurant', 'Thai Restaurant', 'Sushi Restaurant'
    ]
    
    # カテゴリフィルター（揺らぎを考慮してマッチング）
    def is_target_category(cat):
        if not isinstance(cat, str):
            return False
        cat_clean = cat.strip()
        if any(t.lower() in cat_clean.lower() for t in target_categories):
            return True
        return False
        
    df_filtered = df[df['Category'].apply(is_target_category)].copy()
    print(f"Filtered to {len(df_filtered)} targeting restaurants/cafes.")
    
    # 距離フィルターのためのハバーサイン距離計算
    import math
    def get_distance(lat1, lon1, lat2, lon2):
        R = 6371000 # m
        phi1 = math.radians(lat1)
        phi2 = math.radians(lat2)
        dphi = math.radians(lat2 - lat1)
        dlam = math.radians(lon2 - lon1)
        a = math.sin(dphi/2)**2 + math.cos(phi1)*math.cos(phi2)*math.sin(dlam/2)**2
        c = 2 * math.atan2(math.sqrt(a), math.sqrt(1-a))
        return R * c

    # 3. シード駐輪場から半径 2.0 km 以内にある店舗のみをフィルタリング
    valid_stores = []
    for _, row in df_filtered.iterrows():
        store_lat = float(row['Latitude'])
        store_lng = float(row['Longitude'])
        
        in_range = False
        for p in parking_lots:
            p_lat, p_lng = float(p[2]), float(p[3])
            dist = get_distance(p_lat, p_lng, store_lat, store_lng)
            if dist <= 2000.0:  # 2.0 km
                in_range = True
                break
        
        if in_range:
            valid_stores.append(row)
            
    if not valid_stores:
        print("No stores found in 2km range of parking lots.")
        return
        
    df_in_range = pd.DataFrame(valid_stores)
    print(f"Filtered to {len(df_in_range)} stores within 2km of parking lots.")
    
    # 4. 空間バケット（グリッド）サンプリング (緯度経度 0.005 ≒ 約500m)
    df_in_range['grid_lat'] = (df_in_range['Latitude'] / 0.005).round().astype(int)
    df_in_range['grid_lng'] = (df_in_range['Longitude'] / 0.005).round().astype(int)
    df_in_range['grid_key'] = df_in_range['grid_lat'].astype(str) + "_" + df_in_range['grid_lng'].astype(str)
    
    grid_groups = df_in_range.groupby('grid_key')
    grids = list(grid_groups.groups.keys())
    
    sampled_rows = []
    grid_indices = {g: 0 for g in grids}
    max_additional_stores = 30
    existing_ids = {'s1', 's2', 's3', 's4', 's5'}
    
    while len(sampled_rows) < max_additional_stores:
        added_in_this_loop = False
        for g in grids:
            group = grid_groups.get_group(g)
            idx = grid_indices[g]
            
            if idx < len(group):
                row = group.iloc[idx]
                store_id = str(row['Venue ID'])
                
                if store_id not in existing_ids and store_id not in [str(r['Venue ID']) for r in sampled_rows]:
                    sampled_rows.append(row)
                    added_in_this_loop = True
                    
                grid_indices[g] += 1
                
                if len(sampled_rows) >= max_additional_stores:
                    break
        
        if not added_in_this_loop:
            break
            
    print(f"Sampled {len(sampled_rows)} grid-dispersed stores.")
    
    # 5. 特典の自動生成
    def generate_benefit(cat):
        cat_lower = str(cat).lower()
        if 'coffee' in cat_lower or 'caf' in cat_lower or 'tea' in cat_lower:
            return 'お好きなドリンク 50円引き'
        elif 'bakery' in cat_lower:
            return 'パンを1,000円以上お買い上げで焼き菓子1個サービス'
        elif 'dessert' in cat_lower or 'sweet' in cat_lower or 'cupcake' in cat_lower or 'donut' in cat_lower or 'ice cream' in cat_lower:
            return 'ケーキセット 10% OFF'
        elif 'bar' in cat_lower or 'sake' in cat_lower or 'pub' in cat_lower or 'beer' in cat_lower or 'wine' in cat_lower:
            return '最初のワンドリンク無料（ビール含む）'
        elif any(r in cat_lower for r in ['restaurant', 'diner', 'bbq', 'steak', 'pizza', 'chinese', 'italian', 'japanese', 'french', 'indian', 'thai', 'sushi', 'noodle', 'ramen', 'burger', 'sandwich']):
            return 'ディナータイム 10% OFF'
        else:
            return 'お会計から 5% OFF'
            
    # stores.category (store_category ENUM) へのマッピング関数
    def map_to_store_category(cat):
        cat_lower = str(cat).lower()
        if any(w in cat_lower for w in ['coffee', 'caf', 'tea']):
            return 'cafe'
        if 'bakery' in cat_lower:
            return 'bakery'
        if any(w in cat_lower for w in ['dessert', 'sweet', 'cupcake', 'donut', 'ice cream', 'crepe']):
            return 'sweets'
        if any(w in cat_lower for w in ['bar', 'sake', 'pub', 'beer', 'wine']):
            return 'bar'
        if 'shop' in cat_lower or 'store' in cat_lower or 'boutique' in cat_lower or 'retail' in cat_lower:
            return 'retail'
        # デフォルトは restaurant
        return 'restaurant'
            
    # 6. stores テーブルへ挿入 (既存5件はON CONFLICT DO NOTHINGで完全保護)
    # ※ stores テーブルには budget などの詳細カラムはないため、必要なカラムのみをINSERTする
    insert_query = """
    INSERT INTO stores (id, name, category, lat, lng, benefit)
    VALUES %s
    ON CONFLICT (id) DO NOTHING;
    """
    
    cat_counters = {}
    data = []
    for r in sampled_rows:
        cat_enum = map_to_store_category(r['Category'])
        cat_counters[cat_enum] = cat_counters.get(cat_enum, 0) + 1
        
        # 文字化け対策: シードのNameを使わず、綺麗なデモ用の店舗名を自動生成する
        cat_names_jp = {
            'cafe': '提携カフェ',
            'restaurant': '提携レストラン',
            'bar': '提携バー',
            'bakery': '提携ベーカリー',
            'sweets': '提携スイーツ',
            'retail': '提携ショップ'
        }
        base_name = cat_names_jp.get(cat_enum, '提携店舗')
        demo_name = f"{base_name} {cat_counters[cat_enum]}号店"
        
        data.append((
            str(r['Venue ID']), demo_name, cat_enum,
            float(r['Latitude']), float(r['Longitude']),
            generate_benefit(r['Category'])
        ))
        
    execute_values(cursor, insert_query, data, page_size=1000)
    conn.commit()
    print(f"Successfully inserted {len(data)} subset stores into stores table.")

def main():
    print("Starting Phase 2: Data Load & Calculation")
    conn = None
    try:
        conn = get_connection()
        
        load_external_stores(conn)
        load_stores_from_external(conn)
        df_checkins = load_external_checkins(conn)
        calculate_and_load_category_affinity(conn, df_checkins)
        
        print("Phase 2 complete! All data successfully loaded and calculated.")
    except Exception as e:
        print(f"Error during execution: {e}")
        raise
    finally:
        if conn is not None:
            conn.close()

if __name__ == '__main__':
    main()

# Copyright (c) 2026 江藤大晴
# Released under the MIT License.
