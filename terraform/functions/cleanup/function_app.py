import datetime
import logging
import os
import psycopg2
import azure.functions as func

# Create the Azure Functions App instance
app = func.FunctionApp()

# Timer trigger set to run at 00:00:00 on the 1st day of every month
@app.schedule(schedule="0 0 0 1 * *", arg_name="myTimer", run_on_startup=False, use_monitor=False)
def DeleteOldExamData(myTimer: func.TimerRequest) -> None:
    utc_timestamp = datetime.datetime.utcnow().replace(
        tzinfo=datetime.timezone.utc).isoformat()

    if myTimer.past_due:
        logging.info('The timer is past due!')

    logging.info(f"Python timer trigger function started at {utc_timestamp}")

    region = os.environ.get("REGION_FLAG", "unknown")
    database_url = os.environ.get("DATABASE_URL")

    if not database_url:
        logging.error("DATABASE_URL environment variable is missing. Function exiting.")
        return

    try:
        # Connect to PostgreSQL using connection string from Key Vault
        logging.info("Connecting to PostgreSQL database...")
        conn = psycopg2.connect(database_url)
        conn.autocommit = True
        cursor = conn.cursor()

        # Check if PostgreSQL is currently in recovery mode (indicates a read-only replica)
        cursor.execute("SELECT pg_is_in_recovery();")
        is_recovery = cursor.fetchone()[0]

        if is_recovery:
            logging.info(f"Database is in read-only recovery mode (DR Replica in standby). Skipping deletion for region: {region}.")
            cursor.close()
            conn.close()
            return

        # Database is promoted to primary (Read-Write)
        logging.info(f"Database is active (Read-Write). Executing old exam data deletion in region: {region}...")
        cursor.execute("DELETE FROM exam_results WHERE created_at < NOW() - INTERVAL '30 days';")
        deleted_rows = cursor.rowcount
        logging.info(f"Successfully cleaned up {deleted_rows} old exam results (older than 30 days).")

        cursor.close()
        conn.close()

    except psycopg2.DatabaseError as de:
        logging.error(f"PostgreSQL database error occurred: {de}")
    except Exception as e:
        logging.error(f"Unexpected error during clean-up run: {e}")
