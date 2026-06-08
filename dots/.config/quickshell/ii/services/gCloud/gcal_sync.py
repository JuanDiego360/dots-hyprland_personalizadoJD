#!/usr/bin/env python3
import os
import sys
import json
import argparse
from datetime import datetime, timedelta
from google.auth.transport.requests import Request
from google.oauth2.credentials import Credentials
from google_auth_oauthlib.flow import InstalledAppFlow
from googleapiclient.discovery import build
from googleapiclient.errors import HttpError

# If modifying these scopes, delete the file gcal_token.json.
SCOPES = ['https://www.googleapis.com/auth/calendar']

CONFIG_DIR = os.path.expanduser('~/.config/illogical-impulse')
STATE_DIR = os.path.expanduser('~/.local/state/quickshell/user')
CREDENTIALS_PATH = os.path.join(CONFIG_DIR, 'credentials.json')
TOKEN_PATH = os.path.join(STATE_DIR, 'gcal_token.json')

def load_credentials():
    creds = None
    if os.path.exists(TOKEN_PATH):
        try:
            creds = Credentials.from_authorized_user_file(TOKEN_PATH, SCOPES)
        except Exception as e:
            sys.stderr.write(f"Error loading token: {e}\n")
    
    # If there are no (valid) credentials available, let the user log in.
    if not creds or not creds.valid:
        if creds and creds.expired and creds.refresh_token:
            try:
                creds.refresh(Request())
                os.makedirs(os.path.dirname(TOKEN_PATH), exist_ok=True)
                with open(TOKEN_PATH, 'w') as token:
                    token.write(creds.to_json())
            except Exception as e:
                creds = None
        else:
            creds = None
            
    return creds

def run_auth():
    if not os.path.exists(CREDENTIALS_PATH):
        result = {
            "status": "error",
            "error_type": "credentials_missing",
            "message": f"No se encontró credentials.json en {CREDENTIALS_PATH}. Por favor, configúralo."
        }
        print(json.dumps(result))
        sys.exit(0)

    try:
        flow = InstalledAppFlow.from_client_secrets_file(CREDENTIALS_PATH, SCOPES)
        creds = flow.run_local_server(port=0, prompt='consent')
        os.makedirs(os.path.dirname(TOKEN_PATH), exist_ok=True)
        with open(TOKEN_PATH, 'w') as token:
            token.write(creds.to_json())
        print(json.dumps({"status": "success", "message": "Autenticación exitosa. Token guardado."}))
    except Exception as e:
        print(json.dumps({"status": "error", "error_type": "auth_failed", "message": str(e)}))
        sys.exit(1)

def get_calendar_service():
    creds = load_credentials()
    if not creds:
        print(json.dumps({
            "status": "error",
            "error_type": "unauthorized",
            "message": "Requiere autenticación. Por favor ejecuta el comando de autenticación."
        }))
        sys.exit(0)
    return build('calendar', 'v3', credentials=creds)

def list_events(args):
    service = get_calendar_service()
    try:
        start_str = args.start
        end_str = args.end
        
        # Parse or default to current month
        if not start_str:
            now = datetime.utcnow()
            start_dt = datetime(now.year, now.month, 1)
            start_str = start_dt.isoformat() + 'Z'
        else:
            # Check if just date or datetime
            if len(start_str) <= 10: # YYYY-MM-DD
                start_str = start_str + 'T00:00:00Z'
            elif not start_str.endswith('Z') and '+' not in start_str:
                start_str = start_str + 'Z'

        if not end_str:
            now = datetime.utcnow()
            # Default to 35 days after start to cover typical 6-week month layouts
            start_dt = datetime.fromisoformat(start_str.replace('Z', ''))
            end_dt = start_dt + timedelta(days=42)
            end_str = end_dt.isoformat() + 'Z'
        else:
            if len(end_str) <= 10:
                end_str = end_str + 'T23:59:59Z'
            elif not end_str.endswith('Z') and '+' not in end_str:
                end_str = end_str + 'Z'

        events_result = service.events().list(
            calendarId='primary',
            timeMin=start_str,
            timeMax=end_str,
            singleEvents=True,
            orderBy='startTime',
            maxResults=250
        ).execute()
        
        events = events_result.get('items', [])
        
        output_events = []
        for e in events:
            # Handle start/end date or datetime
            start_info = e['start']
            end_info = e['end']
            
            is_all_day = 'date' in start_info
            start_val = start_info.get('dateTime') or start_info.get('date')
            end_val = end_info.get('dateTime') or end_info.get('date')
            
            output_events.append({
                "id": e.get('id'),
                "summary": e.get('summary', '(Sin título)'),
                "description": e.get('description', ''),
                "start": start_val,
                "end": end_val,
                "isAllDay": is_all_day
            })
            
        print(json.dumps({"status": "success", "events": output_events}))
    except HttpError as error:
        print(json.dumps({"status": "error", "error_type": "api_error", "message": str(error)}))
    except Exception as e:
        print(json.dumps({"status": "error", "error_type": "unknown_error", "message": str(e)}))

def create_event(args):
    service = get_calendar_service()
    try:
        start_time = args.start
        end_time = args.end
        
        event_body = {
            'summary': args.summary,
            'description': args.description or '',
        }
        
        if args.all_day:
            event_body['start'] = {'date': start_time}
            event_body['end'] = {'date': end_time}
        else:
            # Ensure ISO format with timezone if missing
            if 'T' not in start_time:
                start_time = start_time + 'T12:00:00'
            if 'T' not in end_time:
                end_time = end_time + 'T13:00:00'
            
            # If timezone offset is not in string, assume local/UTC offset
            # Google Calendar API requires timezone or offset
            # We can use the user's system timezone or default to local formatting
            event_body['start'] = {'dateTime': start_time, 'timeZone': args.timezone}
            event_body['end'] = {'dateTime': end_time, 'timeZone': args.timezone}
            
        event = service.events().insert(calendarId='primary', body=event_body).execute()
        print(json.dumps({"status": "success", "event_id": event.get('id')}))
    except HttpError as error:
        print(json.dumps({"status": "error", "error_type": "api_error", "message": str(error)}))
    except Exception as e:
        print(json.dumps({"status": "error", "error_type": "unknown_error", "message": str(e)}))

def update_event(args):
    service = get_calendar_service()
    try:
        event_id = args.id
        # First retrieve the existing event to patch/update it
        try:
            event = service.events().get(calendarId='primary', eventId=event_id).execute()
        except HttpError as get_err:
            print(json.dumps({"status": "error", "error_type": "not_found", "message": str(get_err)}))
            return
            
        if args.summary is not None:
            event['summary'] = args.summary
        if args.description is not None:
            event['description'] = args.description
            
        if args.start and args.end:
            if args.all_day:
                event['start'] = {'date': args.start}
                event['end'] = {'date': args.end}
            else:
                start_time = args.start
                end_time = args.end
                if 'T' not in start_time:
                    start_time = start_time + 'T12:00:00'
                if 'T' not in end_time:
                    end_time = end_time + 'T13:00:00'
                event['start'] = {'dateTime': start_time, 'timeZone': args.timezone}
                event['end'] = {'dateTime': end_time, 'timeZone': args.timezone}
                
        updated_event = service.events().update(calendarId='primary', eventId=event_id, body=event).execute()
        print(json.dumps({"status": "success", "event_id": updated_event.get('id')}))
    except HttpError as error:
        print(json.dumps({"status": "error", "error_type": "api_error", "message": str(error)}))
    except Exception as e:
        print(json.dumps({"status": "error", "error_type": "unknown_error", "message": str(e)}))

def delete_event(args):
    service = get_calendar_service()
    try:
        service.events().delete(calendarId='primary', eventId=args.id).execute()
        print(json.dumps({"status": "success"}))
    except HttpError as error:
        print(json.dumps({"status": "error", "error_type": "api_error", "message": str(error)}))
    except Exception as e:
        print(json.dumps({"status": "error", "error_type": "unknown_error", "message": str(e)}))

def main():
    parser = argparse.ArgumentParser(description="Google Calendar Sync CLI")
    subparsers = parser.add_subparsers(dest="command", required=True)
    
    # Auth
    subparsers.add_parser("auth", help="Run OAuth flow")
    
    # List
    list_p = subparsers.add_parser("list", help="List events")
    list_p.add_argument("--start", help="Start date (ISO)")
    list_p.add_argument("--end", help="End date (ISO)")
    
    # Create
    create_p = subparsers.add_parser("create", help="Create event")
    create_p.add_argument("--summary", required=True, help="Title of event")
    create_p.add_argument("--start", required=True, help="Start time (ISO / YYYY-MM-DD)")
    create_p.add_argument("--end", required=True, help="End time (ISO / YYYY-MM-DD)")
    create_p.add_argument("--description", help="Description")
    create_p.add_argument("--all-day", action="store_true", help="All day event")
    create_p.add_argument("--timezone", default="America/Bogota", help="Timezone")
    
    # Update
    update_p = subparsers.add_parser("update", help="Update event")
    update_p.add_argument("--id", required=True, help="Event ID")
    update_p.add_argument("--summary", help="Title of event")
    update_p.add_argument("--start", help="Start time (ISO / YYYY-MM-DD)")
    update_p.add_argument("--end", help="End time (ISO / YYYY-MM-DD)")
    update_p.add_argument("--description", help="Description")
    update_p.add_argument("--all-day", action="store_true", help="All day event")
    update_p.add_argument("--timezone", default="America/Bogota", help="Timezone")
    
    # Delete
    delete_p = subparsers.add_parser("delete", help="Delete event")
    delete_p.add_argument("--id", required=True, help="Event ID")
    
    args = parser.parse_args()
    
    if args.command == "auth":
        run_auth()
    elif args.command == "list":
        list_events(args)
    elif args.command == "create":
        create_event(args)
    elif args.command == "update":
        update_event(args)
    elif args.command == "delete":
        delete_event(args)

if __name__ == "__main__":
    main()
