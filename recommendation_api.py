"""
アプリケーション層（API専用サーバー）
=====================================
レコメンド計算ロジックとJSON APIの提供のみに特化。
HTMLやCSSなどの静的ファイルは一切配信しない。

起動: python recommendation_api.py
ポート: 5001（現行 app.py の 5000 と共存可能）
"""

from flask import Flask, request, jsonify
from flask_cors import CORS
from data_store import DataStore

# ------------------------------------------------------------------
# 初期化
# ------------------------------------------------------------------
app = Flask(__name__)
CORS(app)  # WebUIや Flutter からのクロスオリジンリクエストを許可

# データベース層（CSV代用）の初期化
store = DataStore()

# ------------------------------------------------------------------
# ヘルスチェック
# ------------------------------------------------------------------
@app.route('/api/v2/health')
def health():
    """サーバーの稼働状態を確認するエンドポイント"""
    return jsonify({'status': 'ok'})

# ------------------------------------------------------------------
# ユーザー一覧
# ------------------------------------------------------------------
@app.route('/api/v2/users')
def get_users():
    """チェックイン履歴が5件以上あるユーザーからランダムに10件返す"""
    users = store.get_user_ids(min_checkins=5, sample_size=10)
    return jsonify({'users': users})

# ------------------------------------------------------------------
# ランダム位置取得（テスト・デモ用）
# ------------------------------------------------------------------
@app.route('/api/v2/random_location')
def random_location():
    """ランダムな店舗の座標を返す（現在地のシミュレーション用）"""
    loc = store.get_random_venue_location()
    return jsonify(loc)

# ------------------------------------------------------------------
# レコメンドAPI（メインロジック）
# ------------------------------------------------------------------
@app.route('/api/v2/recommend', methods=['POST'])
def recommend():
    """
    位置情報とユーザーIDを受け取り、レコメンド結果をJSONで返す。

    Request Body:
        {
            "user_id": int,
            "lat": float,
            "lng": float
        }

    Response:
        {
            "user_profile": { ... },
            "recommendations": [ ... ]
        }
    """
    data = request.json
    user_id = data.get('user_id')
    current_lat = data.get('lat')
    current_lng = data.get('lng')

    if user_id is None or current_lat is None or current_lng is None:
        return jsonify({'error': 'Missing parameters: user_id, lat, lng are required'}), 400

    # ----- 1. 協調フィルタリングによるベーススコア算出 -----
    target_visited = store.get_user_visited_venues(user_id)
    candidate_scores = {}

    sim_users = store.get_similar_users(user_id, top_n=5)
    if sim_users is not None:
        for sim_user_id, sim_score in sim_users.items():
            user_vector = store.get_user_item_vector(sim_user_id)
            if user_vector is None:
                continue
            visited_items = user_vector[user_vector > 0].index
            for item in visited_items:
                candidate_scores[item] = candidate_scores.get(item, 0) + sim_score

    n_min = store.get_user_min_visit_count(user_id)
    user_categories = store.get_user_visited_categories(user_id)

    # ----- 2. ユーザープロファイル分析（滞在型 vs 通過型） -----
    user_history_df = store.get_user_history(user_id)
    food_count = len(user_history_df[
        user_history_df['Venue Category Name'].str.contains(
            'Food|Restaurant|Bar|Cafe|Nightlife', case=False, na=False
        )
    ])
    travel_shop_count = len(user_history_df[
        user_history_df['Venue Category Name'].str.contains(
            'Train|Station|Shop|Store|Mall', case=False, na=False
        )
    ])
    is_stay_oriented = food_count > travel_shop_count

    # ----- 3. 近隣店舗の抽出（半径2km） -----
    RADIUS_M = 2000
    nearby_venues = store.get_nearby_venues(current_lat, current_lng, radius_m=RADIUS_M)

    # 訪問済み店舗も含めて推薦候補とする（ペナルティで優先度を制御する）

    # ----- 4. 最終スコアの計算 -----
    final_candidates = []
    for venue in nearby_venues:
        # クーポン対象となるのは提携店舗（storesテーブルのデータ）のみ
        if not venue.get('is_partner', False):
            continue

        vid = venue['Venue ID']
        cat_name = str(venue.get('Venue Category Name', ''))

        # 1. 店舗ベース協調スコア (0.0~1.0)
        s_item_cf = min(candidate_scores.get(vid, 0.0), 1.0)
        
        # 2. カテゴリベース協調スコア (0.0~1.0)
        s_cat_cf = store.get_category_affinity(user_categories, cat_name)
        
        # 3. 個人訪問加点 (0.0~1.0)
        m_uv = store.get_user_visit_count(user_id, vid)
        s_personal = min(1.0, m_uv / 10.0)

        # 統合ベーススコア
        s_base = 0.5 * s_item_cf + 0.2 * s_cat_cf + 0.3 * s_personal
        if s_base == 0:
            s_base = 0.05  # フォールバック

        # 4. 距離減衰ブースト
        dist_boost = max(0.1, 1.0 - (venue['distance'] / RADIUS_M))

        # 5. プロファイルブースト
        is_food = 'Food' in cat_name or 'Restaurant' in cat_name or 'Nightlife' in cat_name
        is_travel = 'Train Station' in cat_name or 'Shop' in cat_name

        profile_boost = 1.0
        if is_stay_oriented and is_food:
            profile_boost = 1.5
        elif not is_stay_oriented and is_travel:
            profile_boost = 1.5

        # 6. 訪問回数ペナルティ
        if m_uv == 0:
            p_visit = 1.0
        else:
            delta_n = m_uv - n_min
            p_visit = max(0.4, 0.9 ** delta_n)

        # 最終スコア
        final_score = s_base * dist_boost * profile_boost * p_visit

        # 理由テキストの生成
        if m_uv > 0:
            reason_text = f"🔁 リピートおすすめ（{m_uv}回訪問）"
        elif s_item_cf > 0.1:
            reason_text = "📝 似た嗜好のユーザーがよく利用しています。"
        elif s_cat_cf > 0.3:
            reason_text = "🏷️ あなたが好むカテゴリと関連が高い店舗です。"
        elif is_stay_oriented and is_food:
            reason_text = "【滞在型プロファイル】過去の飲食店履歴から推薦"
        elif not is_stay_oriented and is_travel:
            reason_text = "【通過型プロファイル】利便性重視の移動・買い物傾向から推薦"
        else:
            reason_text = "距離が近く好みに合致"

        venue_copy = venue.copy()
        venue_copy['final_score'] = final_score
        venue_copy['reason'] = reason_text
        final_candidates.append(venue_copy)

    # スコア順にソートし上位10件を返却（抽選用）
    final_candidates.sort(key=lambda x: x['final_score'], reverse=True)
    top_recommendations = final_candidates[:10]

    # ----- 5. レスポンスの組み立て -----
    res = []
    for r in top_recommendations:
        res.append({
            'venue_id': r['Venue ID'],
            'name': r['Name'],
            'category': r['Venue Category Name'],
            'lat': r['Latitude'],
            'lng': r['Longitude'],
            'distance': round(r['distance']),
            'reason': r['reason'],
            'score': round(r['final_score'], 3)
        })

    return jsonify({
        'user_profile': {
            'food_visits': food_count,
            'travel_shop_visits': travel_shop_count,
            'is_stay_oriented': is_stay_oriented
        },
        'recommendations': res
    })


# ------------------------------------------------------------------
# サーバー起動
# ------------------------------------------------------------------
if __name__ == '__main__':
    print("=== Recommendation API Server (Application Tier) ===")
    print("  Port: 5001")
    print("  Endpoints:")
    print("    GET  /api/v2/health")
    print("    GET  /api/v2/users")
    print("    GET  /api/v2/random_location")
    print("    POST /api/v2/recommend")
    print("=" * 50)
    app.run(host='0.0.0.0', port=5001, debug=True)
