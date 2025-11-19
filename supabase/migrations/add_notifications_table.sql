-- Migration: Add Notifications Table
-- Created: 2025-01-19
-- Purpose: In-app notification center for FamQuest

-- Create notifications table
CREATE TABLE IF NOT EXISTS notifications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  family_id UUID NOT NULL REFERENCES families(id) ON DELETE CASCADE,
  type TEXT NOT NULL CHECK (type IN (
    'task_reminder',
    'task_due',
    'task_overdue',
    'approval_requested',
    'task_approved',
    'task_rejected',
    'task_completed',
    'points_earned',
    'badge_awarded',
    'streak_guard',
    'streak_lost',
    'reward_unlocked',
    'family_invite',
    'event_reminder',
    'study_session',
    'other'
  )),
  title TEXT NOT NULL,
  body TEXT NOT NULL,
  data JSONB DEFAULT '{}'::jsonb,
  is_read BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create indexes for performance
CREATE INDEX idx_notifications_user_id ON notifications(user_id);
CREATE INDEX idx_notifications_family_id ON notifications(family_id);
CREATE INDEX idx_notifications_created_at ON notifications(created_at DESC);
CREATE INDEX idx_notifications_is_read ON notifications(is_read) WHERE is_read = FALSE;
CREATE INDEX idx_notifications_type ON notifications(type);

-- Enable Row Level Security (RLS)
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;

-- RLS Policy: Users can only see their own notifications
CREATE POLICY "Users can view own notifications"
  ON notifications
  FOR SELECT
  USING (auth.uid() = user_id);

-- RLS Policy: Users can update their own notifications (mark as read)
CREATE POLICY "Users can update own notifications"
  ON notifications
  FOR UPDATE
  USING (auth.uid() = user_id);

-- RLS Policy: Users can delete their own notifications
CREATE POLICY "Users can delete own notifications"
  ON notifications
  FOR DELETE
  USING (auth.uid() = user_id);

-- RLS Policy: System can insert notifications for users
CREATE POLICY "System can insert notifications"
  ON notifications
  FOR INSERT
  WITH CHECK (true);

-- Function: Create notification helper
CREATE OR REPLACE FUNCTION create_notification(
  p_user_id UUID,
  p_family_id UUID,
  p_type TEXT,
  p_title TEXT,
  p_body TEXT,
  p_data JSONB DEFAULT '{}'::jsonb
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_notification_id UUID;
BEGIN
  INSERT INTO notifications (
    user_id,
    family_id,
    type,
    title,
    body,
    data
  ) VALUES (
    p_user_id,
    p_family_id,
    p_type,
    p_title,
    p_body,
    p_data
  )
  RETURNING id INTO v_notification_id;

  RETURN v_notification_id;
END;
$$;

-- Function: Automatically create task reminder notifications
CREATE OR REPLACE FUNCTION notify_task_due()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_assignee UUID;
  v_family_id UUID;
BEGIN
  -- Only trigger for tasks that are due soon (within 1 hour) and not completed
  IF NEW.status != 'done' AND NEW.due IS NOT NULL THEN
    IF NEW.due - INTERVAL '1 hour' <= NOW() AND NEW.due > NOW() THEN
      -- Get family_id
      SELECT family_id INTO v_family_id FROM tasks WHERE id = NEW.id;

      -- Create notification for each assignee
      IF NEW.assignees IS NOT NULL THEN
        FOR v_assignee IN SELECT unnest(NEW.assignees)
        LOOP
          PERFORM create_notification(
            v_assignee,
            v_family_id,
            'task_due',
            'Task Due Soon',
            'Task "' || NEW.title || '" is due in 1 hour',
            jsonb_build_object('taskId', NEW.id)
          );
        END LOOP;
      END IF;
    END IF;
  END IF;

  RETURN NEW;
END;
$$;

-- Function: Notify on approval request
CREATE OR REPLACE FUNCTION notify_approval_requested()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_parent_id UUID;
  v_family_id UUID;
  v_assignee_name TEXT;
BEGIN
  -- Only trigger when status changes to pending_approval
  IF NEW.status = 'pending_approval' AND (OLD.status IS NULL OR OLD.status != 'pending_approval') THEN
    -- Get family_id and parent user
    SELECT t.family_id INTO v_family_id FROM tasks t WHERE t.id = NEW.id;

    -- Find a parent in the family
    SELECT u.id INTO v_parent_id
    FROM users u
    WHERE u.family_id = v_family_id AND u.role = 'parent'
    LIMIT 1;

    -- Get assignee name
    SELECT u.display_name INTO v_assignee_name
    FROM users u
    WHERE u.id = NEW.assignees[1];

    IF v_parent_id IS NOT NULL THEN
      PERFORM create_notification(
        v_parent_id,
        v_family_id,
        'approval_requested',
        'Task Approval Requested',
        v_assignee_name || ' completed "' || NEW.title || '" and needs approval',
        jsonb_build_object('taskId', NEW.id, 'userId', NEW.assignees[1])
      );
    END IF;
  END IF;

  RETURN NEW;
END;
$$;

-- Function: Notify on task approval/rejection
CREATE OR REPLACE FUNCTION notify_task_approval()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_assignee UUID;
  v_family_id UUID;
BEGIN
  -- Trigger when task is approved or rejected
  IF NEW.status = 'done' AND OLD.status = 'pending_approval' THEN
    SELECT family_id INTO v_family_id FROM tasks WHERE id = NEW.id;

    -- Notify assignees
    IF NEW.assignees IS NOT NULL THEN
      FOR v_assignee IN SELECT unnest(NEW.assignees)
      LOOP
        PERFORM create_notification(
          v_assignee,
          v_family_id,
          'task_approved',
          'Task Approved',
          'Your task "' || NEW.title || '" was approved!',
          jsonb_build_object('taskId', NEW.id, 'points', NEW.points)
        );
      END LOOP;
    END IF;
  ELSIF NEW.status = 'open' AND OLD.status = 'pending_approval' THEN
    SELECT family_id INTO v_family_id FROM tasks WHERE id = NEW.id;

    -- Notify assignees of rejection
    IF NEW.assignees IS NOT NULL THEN
      FOR v_assignee IN SELECT unnest(NEW.assignees)
      LOOP
        PERFORM create_notification(
          v_assignee,
          v_family_id,
          'task_rejected',
          'Task Needs Revision',
          'Task "' || NEW.title || '" needs to be redone',
          jsonb_build_object('taskId', NEW.id)
        );
      END LOOP;
    END IF;
  END IF;

  RETURN NEW;
END;
$$;

-- Create triggers
-- Note: Uncomment these once task triggers are needed
-- CREATE TRIGGER trigger_notify_task_due
--   AFTER UPDATE ON tasks
--   FOR EACH ROW
--   EXECUTE FUNCTION notify_task_due();

-- CREATE TRIGGER trigger_notify_approval_requested
--   AFTER UPDATE ON tasks
--   FOR EACH ROW
--   EXECUTE FUNCTION notify_approval_requested();

-- CREATE TRIGGER trigger_notify_task_approval
--   AFTER UPDATE ON tasks
--   FOR EACH ROW
--   EXECUTE FUNCTION notify_task_approval();

-- Function: Clean up old notifications (older than 30 days)
CREATE OR REPLACE FUNCTION cleanup_old_notifications()
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_deleted_count INTEGER;
BEGIN
  DELETE FROM notifications
  WHERE created_at < NOW() - INTERVAL '30 days'
  RETURNING COUNT(*) INTO v_deleted_count;

  RETURN v_deleted_count;
END;
$$;

-- Create a scheduled job to clean up old notifications (daily at 3 AM)
-- Note: This requires pg_cron extension
-- SELECT cron.schedule(
--   'cleanup-old-notifications',
--   '0 3 * * *',
--   $$SELECT cleanup_old_notifications();$$
-- );

-- Grant permissions
GRANT SELECT, INSERT, UPDATE, DELETE ON notifications TO authenticated;
GRANT EXECUTE ON FUNCTION create_notification TO authenticated;
GRANT EXECUTE ON FUNCTION cleanup_old_notifications TO authenticated;

-- Add comment
COMMENT ON TABLE notifications IS 'In-app notification center for FamQuest users';
COMMENT ON FUNCTION create_notification IS 'Helper function to create notifications with proper structure';
COMMENT ON FUNCTION cleanup_old_notifications IS 'Removes notifications older than 30 days';
