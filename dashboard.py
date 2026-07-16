import streamlit as st
import awswrangler as wr
import pandas as pd
import plotly.express as px

# 1. Page Configuration
st.set_page_config(
    page_title="PS Ingress Platform Analytics",
    page_icon="🛡️",
    layout="wide"
)

st.title("🛡️ Public Sector Ingress Platform - Analytics Dashboard")
st.markdown("This dashboard queries Amazon Athena directly over our partitioned S3 JSON data lake.")

# 2. Query Athena using AWS Wrangler
@st.cache_data(ttl=60)  # Caches data for 60 seconds to prevent hammering Athena
def load_data():
    query = """
    SELECT 
        record_id, 
        clearance, 
        split_part(record_id, '-', 1) as department, -- Extracts GOV, NHS, MOD etc.
        payload 
    FROM records
    """
    # Runs query against your database using your dedicated workgroup
    df = wr.athena.read_sql_query(
        sql=query,
        database="ps_ingress_analytics",
        workgroup="ps-quicksight-analytics-workgroup"
    )
    return df

with st.spinner("Executing query in Amazon Athena..."):
    try:
        df = load_data()
    except Exception as e:
        st.error(f"Failed to connect to Athena: {e}")
        st.info("Make sure your AWS CLI credentials are active in your terminal!")
        st.stop()

# 3. KPI Metrics Row
col1, col2, col3 = st.columns(3)
with col1:
    st.metric("Total Ingested Records", len(df))
with col2:
    st.metric("Active Departments", df['department'].nunique())
with col3:
    st.metric("Unique Clearance Levels", df['clearance'].nunique())

st.markdown("---")

# 4. Interactive Charts Row
chart_col1, chart_col2 = st.columns(2)

with chart_col1:
    st.subheader("📊 Records by Department")
    dept_counts = df['department'].value_counts().reset_index()
    dept_counts.columns = ['Department', 'Count']
    fig_dept = px.bar(dept_counts, x='Department', y='Count', color='Department', template="plotly_dark")
    st.plotly_chart(fig_dept, use_container_width=True)

with chart_col2:
    st.subheader("🛡️ Data Clearance Level Distribution")
    clearance_counts = df['clearance'].value_counts().reset_index()
    clearance_counts.columns = ['Clearance', 'Count']
    fig_clearance = px.pie(clearance_counts, values='Count', names='Clearance', hole=0.4, template="plotly_dark")
    st.plotly_chart(fig_clearance, use_container_width=True)

# 5. Live Data Explorer Row
st.subheader("🔍 Data Lake Raw Explorer")
st.dataframe(df, use_container_width=True)