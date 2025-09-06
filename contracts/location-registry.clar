;; Hawkpass Location Registry - GPS Tracking System
;; Real-time location management for hawker license verification
;; Tracks vendor locations and validates against permitted zones

;; === CONSTANTS ===
(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u200))
(define-constant ERR_INVALID_LOCATION (err u201))
(define-constant ERR_LICENSE_NOT_FOUND (err u202))
(define-constant ERR_ZONE_NOT_FOUND (err u203))
(define-constant ERR_OUTSIDE_ZONE (err u204))
(define-constant ERR_INVALID_COORDINATES (err u205))
(define-constant ERR_HISTORY_FULL (err u206))

;; Coordinate scaling factor (multiply by 1000000 for precision)
(define-constant COORDINATE_SCALE u1000000)

;; Maximum entries in location history per license
(define-constant MAX_HISTORY_ENTRIES u100)

;; Time window for location updates (blocks)
(define-constant MIN_UPDATE_INTERVAL u6) ;; ~1 hour

;; Valid coordinate ranges (scaled)
(define-constant MIN_LATITUDE -90000000)   ;; -90 degrees (scaled)
(define-constant MAX_LATITUDE 90000000)    ;; 90 degrees (scaled)
(define-constant MIN_LONGITUDE -180000000) ;; -180 degrees (scaled)
(define-constant MAX_LONGITUDE 180000000)  ;; 180 degrees (scaled)

;; === DATA MAPS AND VARIABLES ===
;; Zone counter for unique zone IDs
(define-data-var zone-counter uint u0)

;; Location update counter
(define-data-var location-update-counter uint u0)

;; Authorized operators (can manage zones and verify locations)
(define-map operators principal bool)

;; Current locations for each license
(define-map current-locations uint {
    latitude: int,
    longitude: int,
    timestamp: uint,
    accuracy: uint,
    zone-id: (optional uint),
    is-verified: bool
})

;; Location history for audit trail
(define-map location-history uint (list 100 {
    latitude: int,
    longitude: int,
    timestamp: uint,
    accuracy: uint,
    zone-id: (optional uint),
    update-id: uint
}))

;; Permitted zones definition
(define-map permitted-zones uint {
    name: (string-ascii 50),
    center-lat: int,
    center-lon: int,
    radius: uint,
    is-active: bool,
    created-by: principal,
    created-at: uint,
    description: (string-ascii 200)
})

;; Zone assignments for specific licenses
(define-map license-zones uint (list 10 uint))

;; Movement tracking for compliance
(define-map movement-logs uint {
    total-updates: uint,
    last-zone-change: uint,
    violations: uint,
    compliance-score: uint
})

;; === PRIVATE FUNCTIONS ===
;; Check if caller is authorized operator
(define-private (is-operator (user principal))
    (or (is-eq user CONTRACT_OWNER)
        (default-to false (map-get? operators user)))
)

;; Validate coordinate ranges
(define-private (is-valid-coordinate (lat int) (lon int))
    (and 
        (>= lat MIN_LATITUDE)
        (<= lat MAX_LATITUDE)
        (>= lon MIN_LONGITUDE)
        (<= lon MAX_LONGITUDE)
    )
)

;; Calculate distance between two points (simplified)
(define-private (calculate-distance (lat1 int) (lon1 int) (lat2 int) (lon2 int))
    (let (
        (lat-diff (if (> lat1 lat2) (- lat1 lat2) (- lat2 lat1)))
        (lon-diff (if (> lon1 lon2) (- lon1 lon2) (- lon2 lon1)))
    )
        ;; Simplified distance calculation (not geodesic) - convert to uint for comparison
        (to-uint (+ (* lat-diff lat-diff) (* lon-diff lon-diff)))
    )
)

;; Check if location is within permitted zone
(define-private (is-within-zone (lat int) (lon int) (zone-id uint))
    (match (map-get? permitted-zones zone-id)
        zone-info (let (
            (distance (calculate-distance lat lon 
                (get center-lat zone-info) (get center-lon zone-info)))
            (radius-squared (* (get radius zone-info) (get radius zone-info)))
        )
            (and (get is-active zone-info)
                 (<= distance radius-squared))
        )
        false
    )
)

;; Find zone for given coordinates
(define-private (find-zone-for-location (lat int) (lon int))
    ;; Simplified: check first 50 zones (in real implementation would optimize)
    (fold find-matching-zone (list u1 u2 u3 u4 u5 u6 u7 u8 u9 u10
                                  u11 u12 u13 u14 u15 u16 u17 u18 u19 u20
                                  u21 u22 u23 u24 u25 u26 u27 u28 u29 u30
                                  u31 u32 u33 u34 u35 u36 u37 u38 u39 u40
                                  u41 u42 u43 u44 u45 u46 u47 u48 u49 u50) 
          { lat: lat, lon: lon, found: none })
)

;; Helper function for zone finding
(define-private (find-matching-zone (zone-id uint) (context { lat: int, lon: int, found: (optional uint) }))
    (if (is-some (get found context))
        context
        (if (is-within-zone (get lat context) (get lon context) zone-id)
            (merge context { found: (some zone-id) })
            context
        )
    )
)

;; Generate new update ID
(define-private (generate-update-id)
    (let ((new-id (+ (var-get location-update-counter) u1)))
        (var-set location-update-counter new-id)
        new-id
    )
)

;; Add to location history
(define-private (add-to-location-history (license-id uint) (lat int) (lon int) (accuracy uint) (zone-id (optional uint)))
    (let (
        (current-history (default-to (list) (map-get? location-history license-id)))
        (update-id (generate-update-id))
        (new-entry {
            latitude: lat,
            longitude: lon,
            timestamp: stacks-block-height,
            accuracy: accuracy,
            zone-id: zone-id,
            update-id: update-id
        })
    )
        (map-set location-history license-id 
            (unwrap-panic (as-max-len? (append current-history new-entry) u100))
        )
        update-id
    )
)

;; === PUBLIC FUNCTIONS ===
;; Initialize contract
(define-public (initialize)
    (begin
        (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
        (map-set operators CONTRACT_OWNER true)
        (ok "Location registry initialized")
    )
)

;; Add operator (only contract owner)
(define-public (add-operator (new-operator principal))
    (begin
        (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
        (map-set operators new-operator true)
        (ok "Operator added")
    )
)

;; Remove operator
(define-public (remove-operator (operator principal))
    (begin
        (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
        (asserts! (not (is-eq operator CONTRACT_OWNER)) ERR_UNAUTHORIZED)
        (map-delete operators operator)
        (ok "Operator removed")
    )
)

;; Create new permitted zone
(define-public (create-zone (name (string-ascii 50)) (center-lat int) (center-lon int) 
                           (radius uint) (description (string-ascii 200)))
    (let ((zone-id (+ (var-get zone-counter) u1)))
        (asserts! (is-operator tx-sender) ERR_UNAUTHORIZED)
        (asserts! (is-valid-coordinate center-lat center-lon) ERR_INVALID_COORDINATES)
        (asserts! (> radius u0) ERR_INVALID_LOCATION)
        
        (map-set permitted-zones zone-id {
            name: name,
            center-lat: center-lat,
            center-lon: center-lon,
            radius: radius,
            is-active: true,
            created-by: tx-sender,
            created-at: stacks-block-height,
            description: description
        })
        
        (var-set zone-counter zone-id)
        (ok zone-id)
    )
)

;; Update zone status
(define-public (update-zone-status (zone-id uint) (is-active bool))
    (let ((zone-info (unwrap! (map-get? permitted-zones zone-id) ERR_ZONE_NOT_FOUND)))
        (asserts! (is-operator tx-sender) ERR_UNAUTHORIZED)
        
        (map-set permitted-zones zone-id 
            (merge zone-info { is-active: is-active })
        )
        
        (ok "Zone status updated")
    )
)

;; Assign zones to license
(define-public (assign-zones-to-license (license-id uint) (zone-ids (list 10 uint)))
    (begin
        (asserts! (is-operator tx-sender) ERR_UNAUTHORIZED)
        (map-set license-zones license-id zone-ids)
        (ok "Zones assigned to license")
    )
)

;; Update hawker location
(define-public (update-location (license-id uint) (latitude int) (longitude int) (accuracy uint))
    (let (
        (current-time stacks-block-height)
        (zone-result (find-zone-for-location latitude longitude))
        (found-zone-id (get found zone-result))
        (assigned-zones (default-to (list) (map-get? license-zones license-id)))
        (is-in-permitted-zone (if (is-some found-zone-id)
                                (is-some (index-of assigned-zones (unwrap-panic found-zone-id)))
                                false))
    )
        ;; Basic validation
        (asserts! (is-valid-coordinate latitude longitude) ERR_INVALID_COORDINATES)
        (asserts! (> accuracy u0) ERR_INVALID_LOCATION)
        
        ;; Update current location
        (map-set current-locations license-id {
            latitude: latitude,
            longitude: longitude,
            timestamp: current-time,
            accuracy: accuracy,
            zone-id: found-zone-id,
            is-verified: is-in-permitted-zone
        })
        
        ;; Add to history
        (let ((update-id (add-to-location-history license-id latitude longitude accuracy found-zone-id)))
            ;; Update movement tracking
            (let (
                (current-log (default-to { total-updates: u0, last-zone-change: u0, 
                                         violations: u0, compliance-score: u100 } 
                                       (map-get? movement-logs license-id)))
                (new-violations (if is-in-permitted-zone 
                                  (get violations current-log)
                                  (+ (get violations current-log) u1)))
            )
                (map-set movement-logs license-id {
                    total-updates: (+ (get total-updates current-log) u1),
                    last-zone-change: (if (is-some found-zone-id) current-time (get last-zone-change current-log)),
                    violations: new-violations,
                    compliance-score: (if (<= new-violations u5) 
                                       (- u100 (* new-violations u10)) 
                                       u50)
                })
            )
            
            (ok { update-id: update-id, zone-verified: is-in-permitted-zone })
        )
    )
)

;; Verify location against zone requirements
(define-public (verify-location (license-id uint))
    (let ((location (unwrap! (map-get? current-locations license-id) ERR_LICENSE_NOT_FOUND)))
        (asserts! (is-operator tx-sender) ERR_UNAUTHORIZED)
        
        (map-set current-locations license-id 
            (merge location { is-verified: true })
        )
        
        (ok "Location verified")
    )
)

;; === READ-ONLY FUNCTIONS ===
;; Get current location for license
(define-read-only (get-current-location (license-id uint))
    (map-get? current-locations license-id)
)

;; Get location history
(define-read-only (get-location-history (license-id uint))
    (map-get? location-history license-id)
)

;; Get zone information
(define-read-only (get-zone-info (zone-id uint))
    (map-get? permitted-zones zone-id)
)

;; Get zones assigned to license
(define-read-only (get-license-zones (license-id uint))
    (map-get? license-zones license-id)
)

;; Get movement log
(define-read-only (get-movement-log (license-id uint))
    (map-get? movement-logs license-id)
)

;; Check if location is within any permitted zone for license
(define-read-only (is-location-permitted (license-id uint) (latitude int) (longitude int))
    (let ((assigned-zones (default-to (list) (map-get? license-zones license-id))))
        (fold check-zone-permission assigned-zones 
              { lat: latitude, lon: longitude, permitted: false })
    )
)

;; Helper for zone permission check
(define-private (check-zone-permission (zone-id uint) (context { lat: int, lon: int, permitted: bool }))
    (if (get permitted context)
        context
        (merge context { permitted: (is-within-zone (get lat context) (get lon context) zone-id) })
    )
)

;; Get zone counter
(define-read-only (get-zone-counter)
    (var-get zone-counter)
)

;; Get location update counter
(define-read-only (get-update-counter)
    (var-get location-update-counter)
)

;; Check if user is operator
(define-read-only (check-operator (user principal))
    (is-operator user)
)
