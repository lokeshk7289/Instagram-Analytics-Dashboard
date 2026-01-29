import streamlit as st
import pandas as pd
import mysql.connector
import plotly.express as px
import plotly.graph_objects as go

# ------------------ PAGE CONFIG ------------------
st.set_page_config(
    page_title="Instagram Analytics Dashboard",
    page_icon="📊",
    layout="wide"
)

# ------------------ DB CONNECTION ------------------
@st.cache_resource
def get_connection():
    return mysql.connector.connect(
        host="localhost",
        user="root",
        password="Loki@2001",
        database="instagram_analytics"
    )

conn = get_connection()

# ------------------ LOAD DATA ------------------
@st.cache_data
def load_data():
    posts = pd.read_sql("SELECT * FROM post_performance_summary", conn)
    followers = pd.read_sql("SELECT * FROM follower_growth_trends", conn)
    hashtags = pd.read_sql("SELECT * FROM hashtag_performance", conn)
    best_time = pd.read_sql("SELECT * FROM best_posting_times", conn)
    content = pd.read_sql("SELECT * FROM content_type_performance", conn)
    return posts, followers, hashtags, best_time, content

posts, followers, hashtags, best_time, content = load_data()

# ------------------ SIDEBAR ------------------
st.sidebar.title("📌 Filters")

post_type_filter = st.sidebar.multiselect(
    "Select Post Type",
    posts["post_type"].unique(),
    default=posts["post_type"].unique()
)

filtered_posts = posts[posts["post_type"].isin(post_type_filter)]

# ------------------ TITLE ------------------
st.title("📊 Instagram Analytics Dashboard")
st.markdown("### Data-Driven Performance Insights")

# ------------------ KPI METRICS ------------------
col1, col2, col3, col4 = st.columns(4)

col1.metric("📌 Total Posts", len(filtered_posts))
col2.metric("❤️ Avg Engagement Rate", f"{filtered_posts['calculated_engagement_rate'].mean():.2f}%")
col3.metric("👥 Avg Reach", f"{filtered_posts['reach'].mean():,.0f}")
col4.metric("🚀 Total Engagement", f"{filtered_posts['total_engagement'].sum():,}")

st.divider()

# ------------------ TABS ------------------
tab1, tab2, tab3, tab4, tab5 = st.tabs([
    "📈 Engagement",
    "⏰ Posting Time",
    "🔖 Hashtags",
    "🏆 Top Posts",
    "📥 Data"
])

# ------------------ TAB 1: ENGAGEMENT ------------------
with tab1:
    st.subheader("Engagement by Content Type")

    fig = px.bar(
        content,
        x="post_type",
        y="avg_engagement_rate",
        color="post_type",
        text_auto=".2f",
        title="Average Engagement Rate"
    )
    st.plotly_chart(fig, use_container_width=True)

    scatter = px.scatter(
        filtered_posts,
        x="reach",
        y="calculated_engagement_rate",
        size="total_engagement",
        color="post_type",
        title="Engagement Rate vs Reach",
        hover_data=["likes", "comments", "shares", "saves"]
    )
    st.plotly_chart(scatter, use_container_width=True)

# ------------------ TAB 2: POSTING TIME ------------------
with tab2:
    st.subheader("Best Posting Times")

    heatmap = best_time.pivot(
        index="day_of_week",
        columns="hour_of_day",
        values="avg_engagement_rate"
    )

    fig = px.imshow(
        heatmap,
        color_continuous_scale="YlOrRd",
        title="🔥 Best Time Heatmap"
    )
    st.plotly_chart(fig, use_container_width=True)

# ------------------ TAB 3: HASHTAGS ------------------
with tab3:
    st.subheader("Top Hashtags")

    top_hashtags = hashtags.sort_values("avg_total_engagement", ascending=False).head(10)

    fig = px.bar(
        top_hashtags,
        x="avg_total_engagement",
        y="hashtag",
        orientation="h",
        color="avg_total_engagement",
        title="Top Performing Hashtags"
    )
    st.plotly_chart(fig, use_container_width=True)

# ------------------ TAB 4: TOP POSTS ------------------
with tab4:
    st.subheader("Top & Worst Posts")

    top_posts = filtered_posts.sort_values("total_engagement", ascending=False).head(10)
    worst_posts = filtered_posts.sort_values("total_engagement").head(10)

    col1, col2 = st.columns(2)

    col1.write("🏆 Top Posts")
    col1.dataframe(top_posts[[
        "post_id","post_type","total_engagement","calculated_engagement_rate"
    ]])

    col2.write("⚠️ Worst Posts")
    col2.dataframe(worst_posts[[
        "post_id","post_type","total_engagement","calculated_engagement_rate"
    ]])

# ------------------ TAB 5: DATA ------------------
with tab5:
    st.subheader("Raw Data View")
    st.dataframe(filtered_posts)

# ------------------ FOOTER ------------------
st.markdown("---")
st.markdown("✅ **Built with Python, MySQL, Streamlit & Plotly**")