package api

import (
	"context"
	"strings"
	"time"

	"github.com/gofiber/fiber/v2"
	"intracom-server/internal/auth"
	"intracom-server/internal/db"
)

// RecordCallOffer creates a call log entry when a call is initiated
func RecordCallOffer(callerID, target string, callType string) string {
	if db.Pool == nil {
		return ""
	}
	ctx, cancel := context.WithTimeout(context.Background(), 3*time.Second)
	defer cancel()

	receiverID, _, _, err := findUserByTarget(ctx, target)
	if err != nil || receiverID == "" {
		return ""
	}

	if callType == "" {
		callType = "audio"
	}

	var callID string
	err = db.Pool.QueryRow(ctx, `
		INSERT INTO call_history (caller_id, receiver_id, call_type, status, started_at)
		VALUES ($1, $2, $3, 'ringing', CURRENT_TIMESTAMP)
		RETURNING id
	`, callerID, receiverID, callType).Scan(&callID)
	if err != nil {
		return ""
	}
	return callID
}

// RecordCallAnswer updates the call log when the callee accepts the call
func RecordCallAnswer(callerNum, calleeID string) {
	if db.Pool == nil {
		return
	}
	ctx, cancel := context.WithTimeout(context.Background(), 3*time.Second)
	defer cancel()

	callerID, _, _, err := findUserByTarget(ctx, callerNum)
	if err != nil || callerID == "" {
		return
	}

	_, _ = db.Pool.Exec(ctx, `
		UPDATE call_history
		SET status = 'answered', started_at = CURRENT_TIMESTAMP
		WHERE id = (
			SELECT id FROM call_history
			WHERE caller_id = $1 AND receiver_id = $2 AND status = 'ringing'
			ORDER BY started_at DESC
			LIMIT 1
		)
	`, callerID, calleeID)
}

// RecordCallHangup updates the call log when either party ends the call
func RecordCallHangup(userANum, userBNum string) {
	if db.Pool == nil {
		return
	}
	ctx, cancel := context.WithTimeout(context.Background(), 3*time.Second)
	defer cancel()

	userAID, _, _, _ := findUserByTarget(ctx, userANum)
	userBID, _, _, _ := findUserByTarget(ctx, userBNum)
	if userAID == "" || userBID == "" {
		return
	}

	// Update the latest non-ended call between these two users
	_, _ = db.Pool.Exec(ctx, `
		UPDATE call_history
		SET ended_at = CURRENT_TIMESTAMP,
		    duration_seconds = CASE 
		        WHEN status = 'answered' THEN GREATEST(1, ROUND(EXTRACT(EPOCH FROM (CURRENT_TIMESTAMP - started_at))))
		        ELSE 0 
		    END,
		    status = CASE 
		        WHEN status = 'answered' THEN 'completed'
		        ELSE 'missed'
		    END
		WHERE id = (
			SELECT id FROM call_history
			WHERE ((caller_id = $1 AND receiver_id = $2) OR (caller_id = $2 AND receiver_id = $1))
			  AND ended_at IS NULL
			ORDER BY started_at DESC
			LIMIT 1
		)
	`, userAID, userBID)
}

// GET /api/v1/calls/history - List call history for current user
func ListCallHistoryHandler(c *fiber.Ctx) error {
	claims, ok := c.Locals("user").(*auth.JWTClaims)
	if !ok {
		return c.Status(fiber.StatusUnauthorized).JSON(fiber.Map{"success": false, "error": "Unauthorized"})
	}

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	query := `
		SELECT 
			ch.id,
			ch.caller_id,
			u_caller.full_number as caller_number,
			u_caller.display_name as caller_name,
			u_caller.district_name as caller_district,
			ch.receiver_id,
			u_receiver.full_number as receiver_number,
			u_receiver.display_name as receiver_name,
			u_receiver.district_name as receiver_district,
			ch.call_type,
			ch.status,
			COALESCE(ch.duration_seconds, 0) as duration_seconds,
			ch.started_at,
			ch.ended_at
		FROM call_history ch
		JOIN users u_caller ON ch.caller_id = u_caller.id
		JOIN users u_receiver ON ch.receiver_id = u_receiver.id
		WHERE ch.caller_id = $1 OR ch.receiver_id = $1
		ORDER BY ch.started_at DESC
		LIMIT 100
	`

	rows, err := db.Pool.Query(ctx, query, claims.UserID)
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"success": false, "error": "Failed to load call history"})
	}
	defer rows.Close()

	var history []fiber.Map
	for rows.Next() {
		var (
			id, callerID, callerNum, callerName, callerDist   string
			receiverID, receiverNum, receiverName, receiverDist string
			callType, status                                  string
			durationSeconds                                   int
			startedAt                                         time.Time
			endedAt                                           *time.Time
		)

		err := rows.Scan(
			&id,
			&callerID, &callerNum, &callerName, &callerDist,
			&receiverID, &receiverNum, &receiverName, &receiverDist,
			&callType, &status, &durationSeconds, &startedAt, &endedAt,
		)
		if err != nil {
			continue
		}

		isOutgoing := callerID == claims.UserID
		peerNum := receiverNum
		peerName := receiverName
		peerDist := receiverDist
		if !isOutgoing {
			peerNum = callerNum
			peerName = callerName
			peerDist = callerDist
		}

		// Normalize status
		cleanStatus := strings.ToLower(status)
		if cleanStatus == "ringing" {
			cleanStatus = "missed"
		}

		history = append(history, fiber.Map{
			"id":               id,
			"is_outgoing":      isOutgoing,
			"peer_number":      peerNum,
			"peer_name":        peerName,
			"peer_district":    peerDist,
			"call_type":        callType,
			"status":           cleanStatus,
			"duration_seconds": durationSeconds,
			"started_at":       startedAt.Format(time.RFC3339),
			"ended_at":         endedAt,
		})
	}

	return c.JSON(fiber.Map{
		"success": true,
		"data":    history,
	})
}

// DELETE /api/v1/calls/history - Clear all call history for current user
func ClearCallHistoryHandler(c *fiber.Ctx) error {
	claims, ok := c.Locals("user").(*auth.JWTClaims)
	if !ok {
		return c.Status(fiber.StatusUnauthorized).JSON(fiber.Map{"success": false, "error": "Unauthorized"})
	}

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	_, err := db.Pool.Exec(ctx, `
		DELETE FROM call_history
		WHERE caller_id = $1 OR receiver_id = $1
	`, claims.UserID)
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"success": false, "error": "Failed to clear call history"})
	}

	return c.JSON(fiber.Map{
		"success": true,
		"message": "Call history cleared",
	})
}

// DELETE /api/v1/calls/history/:id - Delete a specific call log entry
func DeleteCallLogHandler(c *fiber.Ctx) error {
	claims, ok := c.Locals("user").(*auth.JWTClaims)
	if !ok {
		return c.Status(fiber.StatusUnauthorized).JSON(fiber.Map{"success": false, "error": "Unauthorized"})
	}

	callID := c.Params("id")
	if callID == "" {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"success": false, "error": "Call ID required"})
	}

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	_, err := db.Pool.Exec(ctx, `
		DELETE FROM call_history
		WHERE id = $1 AND (caller_id = $2 OR receiver_id = $2)
	`, callID, claims.UserID)
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"success": false, "error": "Failed to delete call log"})
	}

	return c.JSON(fiber.Map{
		"success": true,
		"message": "Call log deleted",
	})
}
