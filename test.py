@router.delete("/users/delete-all-except-admin", response_model=APIResponse[dict])
async def delete_all_users_except_admin(
    execute: bool = False,
    body: Optional[DeleteUsersInput] = None,
    batch_limit: int = 500,
    db: AsyncSession = Depends(get_db),
    user: UserJWT = Depends(get_user_token)
):
    """
    Delete all users except the admin user with email 'admin@savemom.app' and any additional excluded IDs.
    Handles cascading deletes from dependent tables.
    Only accessible to authenticated users (should be restricted to admin in production).
    
    Query Parameters:
        - dry_run: If True, shows what would be deleted without actually deleting (default: False)
    
    Returns:
        - count: Number of users deleted
        - dry_run: Whether this was a dry run
    """
    try:
        # Default excluded IDs and emails
        excluded_ids = [
            UUID('660f927e-c7e6-493b-a419-701f5b6e7219'),
            UUID('0c9214cc-0fd4-4111-914a-8526c06004db'),
            UUID('1bdfd384-e1d4-4cff-8878-56bc48aabb40'),
            UUID('9e69d03d-86c3-4d1f-9642-9683b0dc017d'),
        ]
        excluded_emails = ['admin@savemom.app']
        
        # Merge any exclusions from request body
        if body:
            if body.exclude_ids:
                excluded_ids.extend(body.exclude_ids)
            if body.exclude_emails:
                excluded_emails.extend(body.exclude_emails)

        # Evaluate total eligible users and then fetch only up to batch_limit
        base_where = (User.email.notin_(excluded_emails), User.id.notin_(excluded_ids))
        total_q = await db.execute(select(func.count()).select_from(User).where(*base_where))
        total_eligible = int(total_q.scalar() or 0)

        # enforce sensible cap
        if batch_limit is None or batch_limit <= 0:
            batch_limit = 500
        if batch_limit > 10000:
            batch_limit = 10000

        result = await db.execute(select(User).where(*base_where).limit(batch_limit))
        users_to_delete = result.scalars().all()
        user_ids_to_delete = [u.id for u in users_to_delete]
        batch_count = len(users_to_delete)
        remaining = max(0, total_eligible - batch_count)
        
        print(f"DEBUG: Found {batch_count} users to delete (batch limit {batch_limit}), total eligible {total_eligible}")
        print(f"DEBUG: User IDs: {[str(uid) for uid in user_ids_to_delete]}")
        
        # If not execute (i.e. execute==False), return dry-run info
        if not execute:
            return APIResponse[dict](
                item={
                    "deleted_count": batch_count,
                    "total_eligible": total_eligible,
                    "remaining": remaining,
                    "executed": False,
                    "message": f"DRY RUN: Would delete {batch_count} users (batch). {remaining} remaining. Protected emails {excluded_emails} and {len(excluded_ids)} protected IDs would remain."
                },
                detail="This is a dry run - no users were actually deleted"
            )
        
        if batch_count == 0:
            return APIResponse[dict](
                item={
                    "deleted_count": 0,
                    "dry_run": False,
                    "message": "No users to delete. All users are protected."
                },
                detail="No deletion performed - no eligible users found"
            )
        
        # Delete dependent records first (cascading delete)
        # This must be done in the correct order to avoid foreign key constraint violations
        
        print(f"DEBUG: Starting cascade delete for {batch_count} users (of {total_eligible} eligible)")
        # Helper: delete in chunks to avoid DB parameter limits for large IN() lists
        async def _delete_in_chunks(db_session: AsyncSession, table, column, ids, chunk_size: int = 300):
            if not ids:
                return
            for i in range(0, len(ids), chunk_size):
                chunk = ids[i:i+chunk_size]
                await db_session.execute(delete(table).where(column.in_(chunk)))
        
        # Delete all records that reference user_id or userId directly
        # Resolve model classes dynamically from models module to avoid import-time errors
        candidate_tables = [
            ("ReminderConfig", "userid"),
            ("LoginHistory", "user_id"),
            ("Message", "sender_id"),
            ("Participant", "user_id"),
            ("ContentLikes", "user_id"),
            ("ContentViews", "user_id"),
            ("ContentComments", "user_id"),
            ("ContentVotes", "user_id"),
            ("PrescriptionMedicine", "user_id"),
            ("UserRoles", "user_id"),
            ("SecurityPolicy", "user_id"),
            ("Notifications", "user_id"),
            ("ReminderSchedules", "user_id"),
            ("SubscriptionPayment", "user_id"),
            ("ProjectMember", "user_id"),
            ("TasksAssignment", "user_id"),
            ("ContentStats", "user_id"),
            ("UserContentSubscription", "user_id"),
            ("FamilyMembers", "userid"),
            ("FamilyRequests", "userId"),
            ("ExternalLink", "user_id"),
            ("Reminder", "user_id"),
            ("BankAccount", "userId"),
            ("ProjectLinks", "user_id"),
        ]

        for model_name, column_name in candidate_tables:
            table = getattr(models, model_name, None)
            if not table:
                print(f"DEBUG: Model {model_name} not found, skipping")
                continue
            if not hasattr(table, column_name):
                print(f"DEBUG: Model {model_name} has no column {column_name}, skipping")
                continue
            column = getattr(table, column_name)
            try:
                await _delete_in_chunks(db, table, column, user_ids_to_delete)
                print(f"DEBUG: Deleted {model_name} records")
            except Exception as e:
                print(f"DEBUG: Error deleting from {model_name}: {str(e)}")
        
        # Delete HealthData (uses UserID not user_id)
        try:
            await _delete_in_chunks(db, HealthData, HealthData.UserID, user_ids_to_delete)
            print(f"DEBUG: Deleted HealthData records")
        except Exception as e:
            print(f"DEBUG: Error deleting HealthData: {str(e)}")
        
        # Delete Content (user_id)
        try:
            await _delete_in_chunks(db, Content, Content.user_id, user_ids_to_delete)
            print(f"DEBUG: Deleted Content records")
        except Exception as e:
            print(f"DEBUG: Error deleting Content: {str(e)}")
        
        # Delete Prescription (user_id)
        try:
            await _delete_in_chunks(db, Prescription, Prescription.user_id, user_ids_to_delete)
            print(f"DEBUG: Deleted Prescription records")
        except Exception as e:
            print(f"DEBUG: Error deleting Prescription: {str(e)}")
        
        # Delete Task (created_by, assigned_to, assigned_by) if model exists
        if TaskModel is not None:
            try:
                if hasattr(TaskModel, 'created_by'):
                    await _delete_in_chunks(db, TaskModel, TaskModel.created_by, user_ids_to_delete)
                if hasattr(TaskModel, 'assigned_to'):
                    await _delete_in_chunks(db, TaskModel, TaskModel.assigned_to, user_ids_to_delete)
                if hasattr(TaskModel, 'assigned_by'):
                    await _delete_in_chunks(db, TaskModel, TaskModel.assigned_by, user_ids_to_delete)
                print(f"DEBUG: Deleted Task records")
            except Exception as e:
                print(f"DEBUG: Error deleting Task records: {str(e)}")

        # Delete UserConnection-like models if present
        UserConnection = getattr(models, 'UserConnection', None)
        if UserConnection is not None:
            try:
                if hasattr(UserConnection, 'user_id'):
                    await _delete_in_chunks(db, UserConnection, UserConnection.user_id, user_ids_to_delete)
                if hasattr(UserConnection, 'handled_by'):
                    await _delete_in_chunks(db, UserConnection, UserConnection.handled_by, user_ids_to_delete)
                print(f"DEBUG: Deleted UserConnection records")
            except Exception as e:
                print(f"DEBUG: Error deleting UserConnection records: {str(e)}")
        
        # Delete Family (motherId, fatherId, createdBy)
        try:
            await _delete_in_chunks(db, Family, Family.motherId, user_ids_to_delete)
            await _delete_in_chunks(db, Family, Family.fatherId, user_ids_to_delete)
            await _delete_in_chunks(db, Family, Family.createdBy, user_ids_to_delete)
            print(f"DEBUG: Deleted Family records")
        except Exception as e:
            print(f"DEBUG: Error deleting Family: {str(e)}")
        
        # Delete Entity (createdBy)
        try:
            await _delete_in_chunks(db, Entity, Entity.createdBy, user_ids_to_delete)
            print(f"DEBUG: Deleted Entity records")
        except Exception as e:
            print(f"DEBUG: Error deleting Entity: {str(e)}")
        
        # Delete Project (created_by)
        try:
            await _delete_in_chunks(db, Project, Project.created_by, user_ids_to_delete)
            print(f"DEBUG: Deleted Project records")
        except Exception as e:
            print(f"DEBUG: Error deleting Project: {str(e)}")
        
        # Delete Role (createdBy)
        try:
            await _delete_in_chunks(db, Role, Role.createdBy, user_ids_to_delete)
            print(f"DEBUG: Deleted Role records")
        except Exception as e:
            print(f"DEBUG: Error deleting Role: {str(e)}")
        
        # Delete Conversation (created_by)
        try:
            await _delete_in_chunks(db, Conversation, Conversation.created_by, user_ids_to_delete)
            print(f"DEBUG: Deleted Conversation records")
        except Exception as e:
            print(f"DEBUG: Error deleting Conversation: {str(e)}")
        
        # Delete UserSubscription (user_id)
        try:
            await _delete_in_chunks(db, UserSubscription, UserSubscription.user_id, user_ids_to_delete)
            print(f"DEBUG: Deleted UserSubscription records")
        except Exception as e:
            print(f"DEBUG: Error deleting UserSubscription: {str(e)}")
        
        # Delete Report (createdBy)
        try:
            await _delete_in_chunks(db, Report, Report.createdBy, user_ids_to_delete)
            print(f"DEBUG: Deleted Report records")
        except Exception as e:
            print(f"DEBUG: Error deleting Report: {str(e)}")
        
        # Finally, delete the User records one-by-one to reduce the
        # chance of hitting DB parameter limits or large-transaction
        # foreign-key constraint surfacing. Commit once after all.
        print(f"DEBUG: About to delete {batch_count} User records (one-by-one)")
        failed_deletes = []
        for uid in user_ids_to_delete:
            try:
                async with db.begin_nested():
                    await db.execute(delete(User).where(User.id == uid))
            except IntegrityError as ie:
                err_detail = str(ie.orig) if hasattr(ie, 'orig') else str(ie)
                print(f"IntegrityError deleting user {uid}: {err_detail}")
                failed_deletes.append({"id": str(uid), "error": err_detail})
            except Exception as e:
                print(f"Error deleting user {uid}: {str(e)}")
                failed_deletes.append({"id": str(uid), "error": str(e)})

        if failed_deletes:
            await db.rollback()
            deleted_ok = batch_count - len(failed_deletes)
            return APIResponse[dict](
                item={
                    "deleted_count": deleted_ok,
                    "executed": True,
                    "failed": failed_deletes,
                    "message": "Some deletions failed due to constraint or other errors. Transaction rolled back."
                },
                detail="Partial failure during deletion"
            )

        await db.commit()
        print(f"DEBUG: User records deleted, committing transaction")
        
        return APIResponse[dict](
            item={
                "deleted_count": batch_count,
                "executed": True,
                "message": f"Successfully deleted {batch_count} users. Protected emails {excluded_emails} and {len(excluded_ids)} protected IDs remain. Remaining eligible: {remaining}"
            },
            detail="All users in this batch deleted successfully"
        )
    
    except Exception as e:
        await db.rollback()
        print(f"Error deleting users: {str(e)}")
        import traceback
        traceback.print_exc()
        raise HTTPException(status_code=500, detail=f"Error deleting users: {str(e)}")