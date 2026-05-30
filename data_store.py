"""
データベース層（CSV代用）
=========================
CSVファイルを読み込み、アプリケーション層に対してデータを提供するモジュール。
将来的にSQLite/PostgreSQL等へ移行する場合は、このモジュールのみ差し替える。
"""

import os
import math
import random
import pandas as pd
import numpy as np
import psycopg2
from sklearn.metrics.pairwise import cosine_similarity

# Supabase Local Postgres のデフォルト接続情報
DB_URL = "postgresql://postgres:postgres@localhost:54322/postgres"

class DataStore:
    """PostgreSQLからデータを読み込み、メモリ上で高速なレコメンド計算を提供するクラス"""

    def __init__(self, db_url=DB_URL):
        """
        Parameters
        ----------
        db_url : str, optional
            PostgreSQLの接続文字列
        """
        print("[DataStore] Connecting to database...")
        conn = psycopg2.connect(db_url)
        
        print("[DataStore] Loading checkins (seed_checkins + used coupons)...")
        # 1. 外部データ (seed_checkins) の読み込み
        query_seed = """
        SELECT user_id AS "User ID", venue_id AS "Venue ID", category_name AS "Venue Category Name"
        FROM seed_checkins
        """
        df_seed = pd.read_sql(query_seed, conn)
        
        # 2. 本番データ (coupons) の読み込み（実質的なチェックイン）
        query_prod = """
        SELECT 
            c.user_id::text AS "User ID", 
            c.store_id AS "Venue ID", 
            s.category::text AS "Venue Category Name"
        FROM coupons c
        JOIN stores s ON c.store_id = s.id
        WHERE c.status = 'used'
        """
        df_prod = pd.read_sql(query_prod, conn)
        
        # 実データとシードデータを結合
        self.df_checkins = pd.concat([df_seed, df_prod], ignore_index=True)

        print("[DataStore] Loading venues (stores + seed_stores)...")
        # 本番の stores とシードの seed_stores を統合して読み込む
        # stores（実際の提携店舗）を優先し、seed_storesからは重複しないものを補完する
        query_venues = """
        SELECT 
            id AS "Venue ID", 
            name AS "Name", 
            category::text AS "Venue Category Name", 
            lat AS "Latitude", 
            lng AS "Longitude"
        FROM stores
        UNION ALL
        SELECT 
            id AS "Venue ID", 
            name AS "Name", 
            category AS "Venue Category Name", 
            lat AS "Latitude", 
            lng AS "Longitude"
        FROM seed_stores
        WHERE id NOT IN (SELECT id FROM stores)
        """
        self.df_venues = pd.read_sql(query_venues, conn)

        print("[DataStore] Precomputing User-Item Similarity Matrix...")
        self.user_item_matrix = self.df_checkins.pivot_table(
            index='User ID', columns='Venue ID', aggfunc='size', fill_value=0
        )
        if not self.user_item_matrix.empty:
            user_sim = cosine_similarity(self.user_item_matrix)
            self.user_sim_df = pd.DataFrame(
                user_sim,
                index=self.user_item_matrix.index,
                columns=self.user_item_matrix.index
            )
        else:
            self.user_sim_df = pd.DataFrame()

        print("[DataStore] Precomputing Category-Category Similarity Matrix...")
        self.user_cat_matrix = self.df_checkins.pivot_table(
            index='User ID', columns='Venue Category Name', aggfunc='size', fill_value=0
        )
        
        # category_affinity は DB に事前計算済みがある場合はそれを優先するロジックも可能だが、
        # メモリ上で再計算した方が早い＆統合データが反映されるため再計算する
        if not self.user_cat_matrix.empty:
            cat_sim = cosine_similarity(self.user_cat_matrix.T)
            self.cat_sim_df = pd.DataFrame(
                cat_sim,
                index=self.user_cat_matrix.columns,
                columns=self.user_cat_matrix.columns
            )
        else:
            self.cat_sim_df = pd.DataFrame()

        conn.close()
        print("[DataStore] Initialization complete.")

    # ------------------------------------------------------------------
    # ユーザー関連
    # ------------------------------------------------------------------

    def get_user_ids(self, min_checkins=5, sample_size=10):
        """チェックイン数が min_checkins 以上のユーザーからランダムに sample_size 件返す"""
        counts = self.df_checkins['User ID'].value_counts()
        valid_users = counts[counts >= min_checkins].index.tolist()
        sampled = random.sample(valid_users, min(sample_size, len(valid_users)))
        return sampled

    def get_user_history(self, user_id):
        """指定ユーザーのチェックイン履歴DataFrameを返す"""
        return self.df_checkins[self.df_checkins['User ID'] == user_id]

    def get_user_visited_venues(self, user_id):
        """指定ユーザーが訪問済みのVenue IDの集合を返す"""
        if user_id not in self.user_item_matrix.index:
            return set()
        user_items = self.user_item_matrix.loc[user_id]
        return set(user_items[user_items > 0].index)

    def get_similar_users(self, user_id, top_n=5):
        """
        指定ユーザーと類似度が高いユーザーの上位 top_n 件を返す。
        
        Returns
        -------
        pd.Series or None
            類似度スコア付きのSeries。ユーザーが存在しない場合はNone。
        """
        if user_id not in self.user_sim_df.index:
            return None
        sim_users = self.user_sim_df[user_id].sort_values(ascending=False).drop(user_id)
        return sim_users.head(top_n)

    def get_user_item_vector(self, user_id):
        """指定ユーザーの アイテム訪問ベクトル を返す"""
        if user_id not in self.user_item_matrix.index:
            return None
        return self.user_item_matrix.loc[user_id]

    def get_user_visit_count(self, user_id, venue_id):
        """指定ユーザーが指定店舗にチェックインした回数を返す"""
        if user_id not in self.user_item_matrix.index or venue_id not in self.user_item_matrix.columns:
            return 0
        return int(self.user_item_matrix.loc[user_id, venue_id])

    def get_user_min_visit_count(self, user_id):
        """ユーザーが訪問した全店舗における最小訪問回数を返す"""
        if user_id not in self.user_item_matrix.index:
            return 0
        user_vector = self.user_item_matrix.loc[user_id]
        visited_counts = user_vector[user_vector > 0]
        if visited_counts.empty:
            return 0
        return int(visited_counts.min())

    def get_user_visited_categories(self, user_id):
        """ユーザーが過去にチェックインしたカテゴリ名の集合を返す"""
        if user_id not in self.user_cat_matrix.index:
            return set()
        user_cat = self.user_cat_matrix.loc[user_id]
        return set(user_cat[user_cat > 0].index)

    def get_category_affinity(self, user_categories, target_category):
        """ユーザーの訪問カテゴリ群と対象カテゴリの間のコサイン類似度の最大値を返す"""
        if target_category not in self.cat_sim_df.index:
            return 0.0
        
        max_affinity = 0.0
        for cat in user_categories:
            if cat in self.cat_sim_df.columns:
                sim = float(self.cat_sim_df.loc[target_category, cat])
                if sim > max_affinity:
                    max_affinity = sim
        return max_affinity

    # ------------------------------------------------------------------
    # 店舗関連
    # ------------------------------------------------------------------

    def get_venue_by_id(self, venue_id):
        """Venue IDから店舗情報の辞書を返す。見つからない場合はNone。"""
        venue = self.df_venues[self.df_venues['Venue ID'] == venue_id]
        if venue.empty:
            return None
        return venue.iloc[0].to_dict()

    def get_random_venue_location(self):
        """ランダムな店舗の位置情報を返す（テスト用シミュレーション）"""
        venue = self.df_venues.sample(1).iloc[0]
        return {
            'lat': venue['Latitude'],
            'lng': venue['Longitude'],
            'name': venue['Name']
        }

    def get_nearby_venues(self, lat, lng, radius_m=1000):
        """
        指定座標から半径 radius_m メートル以内の店舗リストを返す。
        各店舗には 'distance' キーが追加される。
        """
        nearby = []
        for _, venue in self.df_venues.iterrows():
            dist = self._haversine(lat, lng, venue['Latitude'], venue['Longitude'])
            if dist <= radius_m:
                venue_dict = venue.to_dict()
                venue_dict['distance'] = dist
                nearby.append(venue_dict)
        return nearby

    # ------------------------------------------------------------------
    # ユーティリティ
    # ------------------------------------------------------------------

    @staticmethod
    def _haversine(lat1, lon1, lat2, lon2):
        """2点間の距離をメートル単位で計算する（Haversine公式）"""
        R = 6371.0  # 地球の半径 (km)
        dlat = math.radians(lat2 - lat1)
        dlon = math.radians(lon2 - lon1)
        a = (math.sin(dlat / 2) ** 2
             + math.cos(math.radians(lat1))
             * math.cos(math.radians(lat2))
             * math.sin(dlon / 2) ** 2)
        c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))
        return R * c * 1000  # メートルに変換
