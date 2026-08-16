export type Json =
  | string
  | number
  | boolean
  | null
  | { [key: string]: Json | undefined }
  | Json[]

export type Database = {
  // Allows to automatically instantiate createClient with right options
  // instead of createClient<Database, { PostgrestVersion: 'XX' }>(URL, KEY)
  __InternalSupabase: {
    PostgrestVersion: "14.5"
  }
  public: {
    Tables: {
      adherence_alerts: {
        Row: {
          acknowledged_at: string | null
          acknowledged_by: string | null
          checkin_id: string | null
          detected_at: string
          id: string
          kind: Database["public"]["Enums"]["alert_kind"]
          message: string
          organization_id: string
          patient_id: string
          resolved_at: string | null
          resolved_by: string | null
          severity: Database["public"]["Enums"]["alert_severity"]
          status: Database["public"]["Enums"]["alert_status"]
        }
        Insert: {
          acknowledged_at?: string | null
          acknowledged_by?: string | null
          checkin_id?: string | null
          detected_at?: string
          id?: string
          kind: Database["public"]["Enums"]["alert_kind"]
          message: string
          organization_id: string
          patient_id: string
          resolved_at?: string | null
          resolved_by?: string | null
          severity: Database["public"]["Enums"]["alert_severity"]
          status?: Database["public"]["Enums"]["alert_status"]
        }
        Update: {
          acknowledged_at?: string | null
          acknowledged_by?: string | null
          checkin_id?: string | null
          detected_at?: string
          id?: string
          kind?: Database["public"]["Enums"]["alert_kind"]
          message?: string
          organization_id?: string
          patient_id?: string
          resolved_at?: string | null
          resolved_by?: string | null
          severity?: Database["public"]["Enums"]["alert_severity"]
          status?: Database["public"]["Enums"]["alert_status"]
        }
        Relationships: [
          {
            foreignKeyName: "adherence_alerts_acknowledged_by_fkey"
            columns: ["acknowledged_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "adherence_alerts_checkin_id_organization_id_fkey"
            columns: ["checkin_id", "organization_id"]
            isOneToOne: false
            referencedRelation: "meal_checkins"
            referencedColumns: ["id", "organization_id"]
          },
          {
            foreignKeyName: "adherence_alerts_organization_id_fkey"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "adherence_alerts_patient_id_organization_id_fkey"
            columns: ["patient_id", "organization_id"]
            isOneToOne: false
            referencedRelation: "patients"
            referencedColumns: ["id", "organization_id"]
          },
          {
            foreignKeyName: "adherence_alerts_resolved_by_fkey"
            columns: ["resolved_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      anthropometry: {
        Row: {
          assessment_id: string | null
          body_fat_percent: number | null
          created_at: string
          created_by: string
          height_cm: number | null
          id: string
          measured_at: string
          notes: string | null
          organization_id: string
          patient_id: string
          waist_cm: number | null
          weight_kg: number | null
        }
        Insert: {
          assessment_id?: string | null
          body_fat_percent?: number | null
          created_at?: string
          created_by: string
          height_cm?: number | null
          id?: string
          measured_at?: string
          notes?: string | null
          organization_id: string
          patient_id: string
          waist_cm?: number | null
          weight_kg?: number | null
        }
        Update: {
          assessment_id?: string | null
          body_fat_percent?: number | null
          created_at?: string
          created_by?: string
          height_cm?: number | null
          id?: string
          measured_at?: string
          notes?: string | null
          organization_id?: string
          patient_id?: string
          waist_cm?: number | null
          weight_kg?: number | null
        }
        Relationships: [
          {
            foreignKeyName: "anthropometry_assessment_tenant_fkey"
            columns: ["assessment_id", "organization_id"]
            isOneToOne: false
            referencedRelation: "assessments"
            referencedColumns: ["id", "organization_id"]
          },
          {
            foreignKeyName: "anthropometry_created_by_fkey"
            columns: ["created_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "anthropometry_organization_id_fkey"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "anthropometry_patient_tenant_fkey"
            columns: ["patient_id", "organization_id"]
            isOneToOne: false
            referencedRelation: "patients"
            referencedColumns: ["id", "organization_id"]
          },
        ]
      }
      appointments: {
        Row: {
          cancellation_reason: string | null
          created_at: string
          ends_at: string
          external_meeting_url: string | null
          id: string
          location_text: string | null
          modality: Database["public"]["Enums"]["appointment_modality"]
          organization_id: string
          patient_id: string
          patient_note: string | null
          professional_id: string
          requested_by: string
          reviewed_at: string | null
          reviewed_by: string | null
          room_id: string | null
          staff_note: string | null
          starts_at: string
          status: Database["public"]["Enums"]["appointment_status"]
          updated_at: string
        }
        Insert: {
          cancellation_reason?: string | null
          created_at?: string
          ends_at: string
          external_meeting_url?: string | null
          id?: string
          location_text?: string | null
          modality: Database["public"]["Enums"]["appointment_modality"]
          organization_id: string
          patient_id: string
          patient_note?: string | null
          professional_id: string
          requested_by: string
          reviewed_at?: string | null
          reviewed_by?: string | null
          room_id?: string | null
          staff_note?: string | null
          starts_at: string
          status?: Database["public"]["Enums"]["appointment_status"]
          updated_at?: string
        }
        Update: {
          cancellation_reason?: string | null
          created_at?: string
          ends_at?: string
          external_meeting_url?: string | null
          id?: string
          location_text?: string | null
          modality?: Database["public"]["Enums"]["appointment_modality"]
          organization_id?: string
          patient_id?: string
          patient_note?: string | null
          professional_id?: string
          requested_by?: string
          reviewed_at?: string | null
          reviewed_by?: string | null
          room_id?: string | null
          staff_note?: string | null
          starts_at?: string
          status?: Database["public"]["Enums"]["appointment_status"]
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "appointments_organization_id_fkey"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "appointments_patient_id_organization_id_fkey"
            columns: ["patient_id", "organization_id"]
            isOneToOne: false
            referencedRelation: "patients"
            referencedColumns: ["id", "organization_id"]
          },
          {
            foreignKeyName: "appointments_professional_id_fkey"
            columns: ["professional_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "appointments_requested_by_fkey"
            columns: ["requested_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "appointments_reviewed_by_fkey"
            columns: ["reviewed_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "appointments_room_id_organization_id_fkey"
            columns: ["room_id", "organization_id"]
            isOneToOne: false
            referencedRelation: "rooms"
            referencedColumns: ["id", "organization_id"]
          },
        ]
      }
      assessments: {
        Row: {
          allergies: string | null
          assessed_at: string
          clinical_notes: string | null
          created_at: string
          food_preferences: string | null
          food_restrictions: string | null
          id: string
          objective: string | null
          organization_id: string
          patient_id: string
          professional_id: string
          updated_at: string
        }
        Insert: {
          allergies?: string | null
          assessed_at?: string
          clinical_notes?: string | null
          created_at?: string
          food_preferences?: string | null
          food_restrictions?: string | null
          id?: string
          objective?: string | null
          organization_id: string
          patient_id: string
          professional_id: string
          updated_at?: string
        }
        Update: {
          allergies?: string | null
          assessed_at?: string
          clinical_notes?: string | null
          created_at?: string
          food_preferences?: string | null
          food_restrictions?: string | null
          id?: string
          objective?: string | null
          organization_id?: string
          patient_id?: string
          professional_id?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "assessments_organization_id_fkey"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "assessments_patient_tenant_fkey"
            columns: ["patient_id", "organization_id"]
            isOneToOne: false
            referencedRelation: "patients"
            referencedColumns: ["id", "organization_id"]
          },
          {
            foreignKeyName: "assessments_professional_id_fkey"
            columns: ["professional_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      audit_events: {
        Row: {
          action: string
          actor_id: string | null
          created_at: string
          entity_id: string | null
          entity_type: string
          id: number
          metadata: Json
          organization_id: string | null
        }
        Insert: {
          action: string
          actor_id?: string | null
          created_at?: string
          entity_id?: string | null
          entity_type: string
          id?: never
          metadata?: Json
          organization_id?: string | null
        }
        Update: {
          action?: string
          actor_id?: string | null
          created_at?: string
          entity_id?: string | null
          entity_type?: string
          id?: never
          metadata?: Json
          organization_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "audit_events_actor_id_fkey"
            columns: ["actor_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "audit_events_organization_id_fkey"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
        ]
      }
      clinical_drafts: {
        Row: {
          body: string
          created_at: string
          created_by: string
          id: string
          kind: Database["public"]["Enums"]["clinical_draft_kind"]
          organization_id: string
          patient_id: string
          provider: string
          reviewed_at: string | null
          reviewed_by: string | null
          source_snapshot: Json
          status: Database["public"]["Enums"]["clinical_draft_status"]
        }
        Insert: {
          body: string
          created_at?: string
          created_by: string
          id?: string
          kind: Database["public"]["Enums"]["clinical_draft_kind"]
          organization_id: string
          patient_id: string
          provider?: string
          reviewed_at?: string | null
          reviewed_by?: string | null
          source_snapshot?: Json
          status?: Database["public"]["Enums"]["clinical_draft_status"]
        }
        Update: {
          body?: string
          created_at?: string
          created_by?: string
          id?: string
          kind?: Database["public"]["Enums"]["clinical_draft_kind"]
          organization_id?: string
          patient_id?: string
          provider?: string
          reviewed_at?: string | null
          reviewed_by?: string | null
          source_snapshot?: Json
          status?: Database["public"]["Enums"]["clinical_draft_status"]
        }
        Relationships: [
          {
            foreignKeyName: "clinical_drafts_created_by_fkey"
            columns: ["created_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "clinical_drafts_organization_id_fkey"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "clinical_drafts_patient_tenant_fkey"
            columns: ["patient_id", "organization_id"]
            isOneToOne: false
            referencedRelation: "patients"
            referencedColumns: ["id", "organization_id"]
          },
          {
            foreignKeyName: "clinical_drafts_reviewed_by_fkey"
            columns: ["reviewed_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      consultation_summaries: {
        Row: {
          created_at: string
          created_by: string
          id: string
          organization_id: string
          patient_id: string
          summary: string
        }
        Insert: {
          created_at?: string
          created_by: string
          id?: string
          organization_id: string
          patient_id: string
          summary: string
        }
        Update: {
          created_at?: string
          created_by?: string
          id?: string
          organization_id?: string
          patient_id?: string
          summary?: string
        }
        Relationships: [
          {
            foreignKeyName: "consultation_summaries_created_by_fkey"
            columns: ["created_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "consultation_summaries_organization_id_fkey"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "consultation_summaries_patient_tenant_fkey"
            columns: ["patient_id", "organization_id"]
            isOneToOne: false
            referencedRelation: "patients"
            referencedColumns: ["id", "organization_id"]
          },
        ]
      }
      content_library_items: {
        Row: {
          content_type: string
          created_at: string
          created_by: string
          id: string
          organization_id: string
          status: string
          tags: string[]
          title: string
          updated_at: string
        }
        Insert: {
          content_type: string
          created_at?: string
          created_by: string
          id?: string
          organization_id: string
          status?: string
          tags?: string[]
          title: string
          updated_at?: string
        }
        Update: {
          content_type?: string
          created_at?: string
          created_by?: string
          id?: string
          organization_id?: string
          status?: string
          tags?: string[]
          title?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "content_library_items_created_by_fkey"
            columns: ["created_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "content_library_items_organization_id_fkey"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
        ]
      }
      content_library_versions: {
        Row: {
          body: string
          id: string
          item_id: string
          organization_id: string
          published_at: string
          published_by: string
          title: string
          version_no: number
        }
        Insert: {
          body: string
          id?: string
          item_id: string
          organization_id: string
          published_at?: string
          published_by: string
          title: string
          version_no: number
        }
        Update: {
          body?: string
          id?: string
          item_id?: string
          organization_id?: string
          published_at?: string
          published_by?: string
          title?: string
          version_no?: number
        }
        Relationships: [
          {
            foreignKeyName: "content_library_versions_item_id_fkey"
            columns: ["item_id"]
            isOneToOne: false
            referencedRelation: "content_library_items"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "content_library_versions_organization_id_fkey"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "content_library_versions_published_by_fkey"
            columns: ["published_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      equivalency_list_items: {
        Row: {
          calories_per_portion: number
          description: string
          equivalency_list_id: string
          food_id: string | null
          grams: number
          household_measure: string | null
          id: string
          position: number
        }
        Insert: {
          calories_per_portion?: number
          description: string
          equivalency_list_id: string
          food_id?: string | null
          grams: number
          household_measure?: string | null
          id?: string
          position?: number
        }
        Update: {
          calories_per_portion?: number
          description?: string
          equivalency_list_id?: string
          food_id?: string | null
          grams?: number
          household_measure?: string | null
          id?: string
          position?: number
        }
        Relationships: [
          {
            foreignKeyName: "equivalency_list_items_equivalency_list_id_fkey"
            columns: ["equivalency_list_id"]
            isOneToOne: false
            referencedRelation: "equivalency_lists"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "equivalency_list_items_food_id_fkey"
            columns: ["food_id"]
            isOneToOne: false
            referencedRelation: "foods"
            referencedColumns: ["id"]
          },
        ]
      }
      equivalency_lists: {
        Row: {
          calorie_tolerance_pct: number
          created_at: string
          created_by: string | null
          description: string | null
          id: string
          is_active: boolean
          macro_group: string
          organization_id: string | null
          target_calories: number
          title: string
          updated_at: string
        }
        Insert: {
          calorie_tolerance_pct?: number
          created_at?: string
          created_by?: string | null
          description?: string | null
          id?: string
          is_active?: boolean
          macro_group: string
          organization_id?: string | null
          target_calories: number
          title: string
          updated_at?: string
        }
        Update: {
          calorie_tolerance_pct?: number
          created_at?: string
          created_by?: string | null
          description?: string | null
          id?: string
          is_active?: boolean
          macro_group?: string
          organization_id?: string | null
          target_calories?: number
          title?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "equivalency_lists_organization_id_fkey"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
        ]
      }
      follow_up_actions: {
        Row: {
          action_type: string
          alert_id: string
          created_at: string
          created_by: string
          id: string
          note: string | null
          organization_id: string
          patient_id: string
        }
        Insert: {
          action_type: string
          alert_id: string
          created_at?: string
          created_by: string
          id?: string
          note?: string | null
          organization_id: string
          patient_id: string
        }
        Update: {
          action_type?: string
          alert_id?: string
          created_at?: string
          created_by?: string
          id?: string
          note?: string | null
          organization_id?: string
          patient_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "follow_up_actions_alert_id_fkey"
            columns: ["alert_id"]
            isOneToOne: false
            referencedRelation: "adherence_alerts"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "follow_up_actions_alert_id_fkey"
            columns: ["alert_id"]
            isOneToOne: false
            referencedRelation: "follow_up_queue"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "follow_up_actions_created_by_fkey"
            columns: ["created_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "follow_up_actions_organization_id_fkey"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "follow_up_actions_patient_id_fkey"
            columns: ["patient_id"]
            isOneToOne: false
            referencedRelation: "patients"
            referencedColumns: ["id"]
          },
        ]
      }
      food_components: {
        Row: {
          component_food_id: string
          created_at: string
          grams: number
          organization_id: string
          parent_food_id: string
          position: number
        }
        Insert: {
          component_food_id: string
          created_at?: string
          grams: number
          organization_id: string
          parent_food_id: string
          position?: number
        }
        Update: {
          component_food_id?: string
          created_at?: string
          grams?: number
          organization_id?: string
          parent_food_id?: string
          position?: number
        }
        Relationships: [
          {
            foreignKeyName: "food_components_component_food_id_fkey"
            columns: ["component_food_id"]
            isOneToOne: false
            referencedRelation: "foods"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "food_components_organization_id_fkey"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "food_components_parent_food_id_fkey"
            columns: ["parent_food_id"]
            isOneToOne: false
            referencedRelation: "foods"
            referencedColumns: ["id"]
          },
        ]
      }
      food_nutrient_values: {
        Row: {
          amount_per_100g: number | null
          created_at: string
          data_version: string
          food_id: string
          nutrient_id: string
          source_basis: string
        }
        Insert: {
          amount_per_100g?: number | null
          created_at?: string
          data_version: string
          food_id: string
          nutrient_id: string
          source_basis?: string
        }
        Update: {
          amount_per_100g?: number | null
          created_at?: string
          data_version?: string
          food_id?: string
          nutrient_id?: string
          source_basis?: string
        }
        Relationships: [
          {
            foreignKeyName: "food_nutrient_values_food_id_fkey"
            columns: ["food_id"]
            isOneToOne: false
            referencedRelation: "foods"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "food_nutrient_values_nutrient_id_fkey"
            columns: ["nutrient_id"]
            isOneToOne: false
            referencedRelation: "nutrients"
            referencedColumns: ["id"]
          },
        ]
      }
      food_sources: {
        Row: {
          attribution_text: string
          code: string
          dataset_version: string
          id: string
          imported_at: string
          license_name: string
          license_url: string | null
          name: string
          released_on: string | null
        }
        Insert: {
          attribution_text: string
          code: string
          dataset_version: string
          id?: string
          imported_at?: string
          license_name: string
          license_url?: string | null
          name: string
          released_on?: string | null
        }
        Update: {
          attribution_text?: string
          code?: string
          dataset_version?: string
          id?: string
          imported_at?: string
          license_name?: string
          license_url?: string | null
          name?: string
          released_on?: string | null
        }
        Relationships: []
      }
      food_user_preferences: {
        Row: {
          food_id: string
          is_favorite: boolean
          last_used_at: string | null
          updated_at: string
          user_id: string
        }
        Insert: {
          food_id: string
          is_favorite?: boolean
          last_used_at?: string | null
          updated_at?: string
          user_id: string
        }
        Update: {
          food_id?: string
          is_favorite?: boolean
          last_used_at?: string | null
          updated_at?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "food_user_preferences_food_id_fkey"
            columns: ["food_id"]
            isOneToOne: false
            referencedRelation: "foods"
            referencedColumns: ["id"]
          },
        ]
      }
      foods: {
        Row: {
          availability_tags: string[]
          catalog_kind: Database["public"]["Enums"]["catalog_kind"]
          cost_band: string | null
          created_at: string
          created_by: string | null
          cultural_tags: string[]
          diet_tags: string[]
          edible_portion_pct: number
          household_measure_grams: number | null
          household_measure_label: string | null
          id: string
          is_active: boolean
          name: string
          organization_id: string | null
          portion_count: number | null
          preference_tags: string[]
          preparation_state: string
          render_path: string | null
          restriction_tags: string[]
          review_status: string
          reviewed_at: string | null
          reviewed_by: string | null
          search_terms: string[]
          serving_grams: number | null
          source_accessed_on: string | null
          source_food_code: string | null
          source_id: string | null
          source_reference: string | null
          source_reliability: number | null
          updated_at: string
          yield_grams: number | null
        }
        Insert: {
          availability_tags?: string[]
          catalog_kind?: Database["public"]["Enums"]["catalog_kind"]
          cost_band?: string | null
          created_at?: string
          created_by?: string | null
          cultural_tags?: string[]
          diet_tags?: string[]
          edible_portion_pct?: number
          household_measure_grams?: number | null
          household_measure_label?: string | null
          id?: string
          is_active?: boolean
          name: string
          organization_id?: string | null
          portion_count?: number | null
          preference_tags?: string[]
          preparation_state?: string
          render_path?: string | null
          restriction_tags?: string[]
          review_status?: string
          reviewed_at?: string | null
          reviewed_by?: string | null
          search_terms?: string[]
          serving_grams?: number | null
          source_accessed_on?: string | null
          source_food_code?: string | null
          source_id?: string | null
          source_reference?: string | null
          source_reliability?: number | null
          updated_at?: string
          yield_grams?: number | null
        }
        Update: {
          availability_tags?: string[]
          catalog_kind?: Database["public"]["Enums"]["catalog_kind"]
          cost_band?: string | null
          created_at?: string
          created_by?: string | null
          cultural_tags?: string[]
          diet_tags?: string[]
          edible_portion_pct?: number
          household_measure_grams?: number | null
          household_measure_label?: string | null
          id?: string
          is_active?: boolean
          name?: string
          organization_id?: string | null
          portion_count?: number | null
          preference_tags?: string[]
          preparation_state?: string
          render_path?: string | null
          restriction_tags?: string[]
          review_status?: string
          reviewed_at?: string | null
          reviewed_by?: string | null
          search_terms?: string[]
          serving_grams?: number | null
          source_accessed_on?: string | null
          source_food_code?: string | null
          source_id?: string | null
          source_reference?: string | null
          source_reliability?: number | null
          updated_at?: string
          yield_grams?: number | null
        }
        Relationships: [
          {
            foreignKeyName: "foods_created_by_fkey"
            columns: ["created_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "foods_organization_id_fkey"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "foods_reviewed_by_fkey"
            columns: ["reviewed_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "foods_source_id_fkey"
            columns: ["source_id"]
            isOneToOne: false
            referencedRelation: "food_sources"
            referencedColumns: ["id"]
          },
        ]
      }
      form_assignments: {
        Row: {
          assigned_at: string
          assigned_by: string
          id: string
          organization_id: string
          patient_id: string
          status: Database["public"]["Enums"]["form_assignment_status"]
          submitted_at: string | null
          version_id: string
        }
        Insert: {
          assigned_at?: string
          assigned_by: string
          id?: string
          organization_id: string
          patient_id: string
          status?: Database["public"]["Enums"]["form_assignment_status"]
          submitted_at?: string | null
          version_id: string
        }
        Update: {
          assigned_at?: string
          assigned_by?: string
          id?: string
          organization_id?: string
          patient_id?: string
          status?: Database["public"]["Enums"]["form_assignment_status"]
          submitted_at?: string | null
          version_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "form_assignments_assigned_by_fkey"
            columns: ["assigned_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "form_assignments_organization_id_fkey"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "form_assignments_patient_tenant_fkey"
            columns: ["patient_id", "organization_id"]
            isOneToOne: false
            referencedRelation: "patients"
            referencedColumns: ["id", "organization_id"]
          },
          {
            foreignKeyName: "form_assignments_version_id_fkey"
            columns: ["version_id"]
            isOneToOne: false
            referencedRelation: "form_template_versions"
            referencedColumns: ["id"]
          },
        ]
      }
      form_fields: {
        Row: {
          field_type: Database["public"]["Enums"]["form_field_type"]
          id: string
          label: string
          options: Json
          organization_id: string
          position: number
          required: boolean
          version_id: string
        }
        Insert: {
          field_type: Database["public"]["Enums"]["form_field_type"]
          id?: string
          label: string
          options?: Json
          organization_id: string
          position: number
          required?: boolean
          version_id: string
        }
        Update: {
          field_type?: Database["public"]["Enums"]["form_field_type"]
          id?: string
          label?: string
          options?: Json
          organization_id?: string
          position?: number
          required?: boolean
          version_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "form_fields_organization_id_fkey"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "form_fields_version_id_fkey"
            columns: ["version_id"]
            isOneToOne: false
            referencedRelation: "form_template_versions"
            referencedColumns: ["id"]
          },
        ]
      }
      form_responses: {
        Row: {
          assignment_id: string
          created_by: string
          id: string
          organization_id: string
          patient_id: string
          status: Database["public"]["Enums"]["form_assignment_status"]
          submitted_at: string | null
          updated_at: string
          values: Json
          version_id: string
        }
        Insert: {
          assignment_id: string
          created_by: string
          id?: string
          organization_id: string
          patient_id: string
          status?: Database["public"]["Enums"]["form_assignment_status"]
          submitted_at?: string | null
          updated_at?: string
          values?: Json
          version_id: string
        }
        Update: {
          assignment_id?: string
          created_by?: string
          id?: string
          organization_id?: string
          patient_id?: string
          status?: Database["public"]["Enums"]["form_assignment_status"]
          submitted_at?: string | null
          updated_at?: string
          values?: Json
          version_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "form_responses_assignment_id_fkey"
            columns: ["assignment_id"]
            isOneToOne: false
            referencedRelation: "form_assignments"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "form_responses_created_by_fkey"
            columns: ["created_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "form_responses_organization_id_fkey"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "form_responses_patient_tenant_fkey"
            columns: ["patient_id", "organization_id"]
            isOneToOne: false
            referencedRelation: "patients"
            referencedColumns: ["id", "organization_id"]
          },
          {
            foreignKeyName: "form_responses_version_id_fkey"
            columns: ["version_id"]
            isOneToOne: false
            referencedRelation: "form_template_versions"
            referencedColumns: ["id"]
          },
        ]
      }
      form_template_versions: {
        Row: {
          id: string
          organization_id: string
          published_at: string
          published_by: string
          template_id: string
          title: string
          version_no: number
        }
        Insert: {
          id?: string
          organization_id: string
          published_at?: string
          published_by: string
          template_id: string
          title: string
          version_no: number
        }
        Update: {
          id?: string
          organization_id?: string
          published_at?: string
          published_by?: string
          template_id?: string
          title?: string
          version_no?: number
        }
        Relationships: [
          {
            foreignKeyName: "form_template_versions_organization_id_fkey"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "form_template_versions_published_by_fkey"
            columns: ["published_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "form_template_versions_template_id_fkey"
            columns: ["template_id"]
            isOneToOne: false
            referencedRelation: "form_templates"
            referencedColumns: ["id"]
          },
        ]
      }
      form_templates: {
        Row: {
          created_at: string
          created_by: string
          id: string
          name: string
          organization_id: string
          purpose: string
          status: string
        }
        Insert: {
          created_at?: string
          created_by: string
          id?: string
          name: string
          organization_id: string
          purpose?: string
          status?: string
        }
        Update: {
          created_at?: string
          created_by?: string
          id?: string
          name?: string
          organization_id?: string
          purpose?: string
          status?: string
        }
        Relationships: [
          {
            foreignKeyName: "form_templates_created_by_fkey"
            columns: ["created_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "form_templates_organization_id_fkey"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
        ]
      }
      lab_results: {
        Row: {
          assessment_id: string | null
          attachment_name: string | null
          attachment_url: string | null
          collected_on: string
          created_at: string
          created_by: string
          id: string
          notes: string | null
          organization_id: string
          patient_id: string
          reference_range: string | null
          result_value: number | null
          test_name: string
          unit: string | null
        }
        Insert: {
          assessment_id?: string | null
          attachment_name?: string | null
          attachment_url?: string | null
          collected_on: string
          created_at?: string
          created_by: string
          id?: string
          notes?: string | null
          organization_id: string
          patient_id: string
          reference_range?: string | null
          result_value?: number | null
          test_name: string
          unit?: string | null
        }
        Update: {
          assessment_id?: string | null
          attachment_name?: string | null
          attachment_url?: string | null
          collected_on?: string
          created_at?: string
          created_by?: string
          id?: string
          notes?: string | null
          organization_id?: string
          patient_id?: string
          reference_range?: string | null
          result_value?: number | null
          test_name?: string
          unit?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "lab_results_assessment_tenant_fkey"
            columns: ["assessment_id", "organization_id"]
            isOneToOne: false
            referencedRelation: "assessments"
            referencedColumns: ["id", "organization_id"]
          },
          {
            foreignKeyName: "lab_results_created_by_fkey"
            columns: ["created_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "lab_results_organization_id_fkey"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "lab_results_patient_tenant_fkey"
            columns: ["patient_id", "organization_id"]
            isOneToOne: false
            referencedRelation: "patients"
            referencedColumns: ["id", "organization_id"]
          },
        ]
      }
      meal_checkin_photos: {
        Row: {
          created_at: string
          created_by: string
          drive_file_id: string
          drive_web_url: string | null
          file_name: string
          id: string
          meal_checkin_id: string
          meal_id: string
          occurred_on: string
          organization_id: string
          patient_id: string
        }
        Insert: {
          created_at?: string
          created_by: string
          drive_file_id: string
          drive_web_url?: string | null
          file_name: string
          id?: string
          meal_checkin_id: string
          meal_id: string
          occurred_on: string
          organization_id: string
          patient_id: string
        }
        Update: {
          created_at?: string
          created_by?: string
          drive_file_id?: string
          drive_web_url?: string | null
          file_name?: string
          id?: string
          meal_checkin_id?: string
          meal_id?: string
          occurred_on?: string
          organization_id?: string
          patient_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "meal_checkin_photos_created_by_fkey"
            columns: ["created_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "meal_checkin_photos_meal_checkin_id_organization_id_fkey"
            columns: ["meal_checkin_id", "organization_id"]
            isOneToOne: false
            referencedRelation: "meal_checkins"
            referencedColumns: ["id", "organization_id"]
          },
          {
            foreignKeyName: "meal_checkin_photos_meal_id_organization_id_fkey"
            columns: ["meal_id", "organization_id"]
            isOneToOne: false
            referencedRelation: "meals"
            referencedColumns: ["id", "organization_id"]
          },
          {
            foreignKeyName: "meal_checkin_photos_organization_id_fkey"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "meal_checkin_photos_patient_id_organization_id_fkey"
            columns: ["patient_id", "organization_id"]
            isOneToOne: false
            referencedRelation: "patients"
            referencedColumns: ["id", "organization_id"]
          },
        ]
      }
      meal_checkins: {
        Row: {
          created_at: string
          created_by: string
          energy: number | null
          help_requested: boolean
          hunger_before: number | null
          id: string
          meal_id: string
          mood: number | null
          note: string | null
          occurred_on: string
          organization_id: string
          patient_id: string
          plan_version_id: string
          reaction_suspected: boolean
          satiety_after: number | null
          sleep_quality: number | null
          state: Database["public"]["Enums"]["checkin_state"]
          substitution_request_id: string | null
          symptom_intensity: number | null
          symptoms: string | null
          updated_at: string
        }
        Insert: {
          created_at?: string
          created_by: string
          energy?: number | null
          help_requested?: boolean
          hunger_before?: number | null
          id?: string
          meal_id: string
          mood?: number | null
          note?: string | null
          occurred_on?: string
          organization_id: string
          patient_id: string
          plan_version_id: string
          reaction_suspected?: boolean
          satiety_after?: number | null
          sleep_quality?: number | null
          state: Database["public"]["Enums"]["checkin_state"]
          substitution_request_id?: string | null
          symptom_intensity?: number | null
          symptoms?: string | null
          updated_at?: string
        }
        Update: {
          created_at?: string
          created_by?: string
          energy?: number | null
          help_requested?: boolean
          hunger_before?: number | null
          id?: string
          meal_id?: string
          mood?: number | null
          note?: string | null
          occurred_on?: string
          organization_id?: string
          patient_id?: string
          plan_version_id?: string
          reaction_suspected?: boolean
          satiety_after?: number | null
          sleep_quality?: number | null
          state?: Database["public"]["Enums"]["checkin_state"]
          substitution_request_id?: string | null
          symptom_intensity?: number | null
          symptoms?: string | null
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "meal_checkins_created_by_fkey"
            columns: ["created_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "meal_checkins_meal_id_organization_id_fkey"
            columns: ["meal_id", "organization_id"]
            isOneToOne: false
            referencedRelation: "meals"
            referencedColumns: ["id", "organization_id"]
          },
          {
            foreignKeyName: "meal_checkins_organization_id_fkey"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "meal_checkins_patient_id_organization_id_fkey"
            columns: ["patient_id", "organization_id"]
            isOneToOne: false
            referencedRelation: "patients"
            referencedColumns: ["id", "organization_id"]
          },
          {
            foreignKeyName: "meal_checkins_plan_version_id_organization_id_fkey"
            columns: ["plan_version_id", "organization_id"]
            isOneToOne: false
            referencedRelation: "plan_versions"
            referencedColumns: ["id", "organization_id"]
          },
          {
            foreignKeyName: "meal_checkins_substitution_request_id_fkey"
            columns: ["substitution_request_id"]
            isOneToOne: false
            referencedRelation: "substitution_requests"
            referencedColumns: ["id"]
          },
        ]
      }
      meal_item_substitutions: {
        Row: {
          created_at: string
          created_by: string
          description: string
          grams: number
          id: string
          is_active: boolean
          meal_item_id: string
          nutrient_snapshot: Json
          organization_id: string
          plan_version_id: string
          professional_note: string | null
          substitute_food_id: string | null
          unit: string
          updated_at: string
        }
        Insert: {
          created_at?: string
          created_by: string
          description: string
          grams: number
          id?: string
          is_active?: boolean
          meal_item_id: string
          nutrient_snapshot?: Json
          organization_id: string
          plan_version_id: string
          professional_note?: string | null
          substitute_food_id?: string | null
          unit?: string
          updated_at?: string
        }
        Update: {
          created_at?: string
          created_by?: string
          description?: string
          grams?: number
          id?: string
          is_active?: boolean
          meal_item_id?: string
          nutrient_snapshot?: Json
          organization_id?: string
          plan_version_id?: string
          professional_note?: string | null
          substitute_food_id?: string | null
          unit?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "meal_item_substitutions_created_by_fkey"
            columns: ["created_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "meal_item_substitutions_meal_item_id_organization_id_fkey"
            columns: ["meal_item_id", "organization_id"]
            isOneToOne: false
            referencedRelation: "meal_items"
            referencedColumns: ["id", "organization_id"]
          },
          {
            foreignKeyName: "meal_item_substitutions_organization_id_fkey"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "meal_item_substitutions_plan_version_id_organization_id_fkey"
            columns: ["plan_version_id", "organization_id"]
            isOneToOne: false
            referencedRelation: "plan_versions"
            referencedColumns: ["id", "organization_id"]
          },
          {
            foreignKeyName: "meal_item_substitutions_substitute_food_id_fkey"
            columns: ["substitute_food_id"]
            isOneToOne: false
            referencedRelation: "foods"
            referencedColumns: ["id"]
          },
        ]
      }
      meal_items: {
        Row: {
          description: string
          food_id: string | null
          grams: number
          id: string
          meal_id: string
          notes: string | null
          nutrient_snapshot: Json
          organization_id: string
          position: number
          quantity: number
          unit: string
        }
        Insert: {
          description: string
          food_id?: string | null
          grams: number
          id?: string
          meal_id: string
          notes?: string | null
          nutrient_snapshot?: Json
          organization_id: string
          position: number
          quantity: number
          unit: string
        }
        Update: {
          description?: string
          food_id?: string | null
          grams?: number
          id?: string
          meal_id?: string
          notes?: string | null
          nutrient_snapshot?: Json
          organization_id?: string
          position?: number
          quantity?: number
          unit?: string
        }
        Relationships: [
          {
            foreignKeyName: "meal_items_food_id_fkey"
            columns: ["food_id"]
            isOneToOne: false
            referencedRelation: "foods"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "meal_items_meal_id_organization_id_fkey"
            columns: ["meal_id", "organization_id"]
            isOneToOne: false
            referencedRelation: "meals"
            referencedColumns: ["id", "organization_id"]
          },
          {
            foreignKeyName: "meal_items_organization_id_fkey"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
        ]
      }
      meals: {
        Row: {
          equivalency_list_id: string | null
          id: string
          label: string
          organization_id: string
          plan_day_id: string
          position: number
          suggested_time: string | null
        }
        Insert: {
          equivalency_list_id?: string | null
          id?: string
          label: string
          organization_id: string
          plan_day_id: string
          position: number
          suggested_time?: string | null
        }
        Update: {
          equivalency_list_id?: string | null
          id?: string
          label?: string
          organization_id?: string
          plan_day_id?: string
          position?: number
          suggested_time?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "meals_equivalency_list_id_fkey"
            columns: ["equivalency_list_id"]
            isOneToOne: false
            referencedRelation: "equivalency_lists"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "meals_organization_id_fkey"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "meals_plan_day_id_organization_id_fkey"
            columns: ["plan_day_id", "organization_id"]
            isOneToOne: false
            referencedRelation: "plan_days"
            referencedColumns: ["id", "organization_id"]
          },
        ]
      }
      memberships: {
        Row: {
          created_at: string
          id: string
          organization_id: string
          role: Database["public"]["Enums"]["organization_role"]
          status: Database["public"]["Enums"]["membership_status"]
          supervisor_id: string | null
          updated_at: string
          user_id: string
        }
        Insert: {
          created_at?: string
          id?: string
          organization_id: string
          role: Database["public"]["Enums"]["organization_role"]
          status?: Database["public"]["Enums"]["membership_status"]
          supervisor_id?: string | null
          updated_at?: string
          user_id: string
        }
        Update: {
          created_at?: string
          id?: string
          organization_id?: string
          role?: Database["public"]["Enums"]["organization_role"]
          status?: Database["public"]["Enums"]["membership_status"]
          supervisor_id?: string | null
          updated_at?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "memberships_organization_id_fkey"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "memberships_supervisor_id_fkey"
            columns: ["supervisor_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "memberships_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      nutrients: {
        Row: {
          code: string
          decimals: number
          id: string
          name: string
          sort_order: number
          unit: string
        }
        Insert: {
          code: string
          decimals?: number
          id?: string
          name: string
          sort_order?: number
          unit: string
        }
        Update: {
          code?: string
          decimals?: number
          id?: string
          name?: string
          sort_order?: number
          unit?: string
        }
        Relationships: []
      }
      organization_branding: {
        Row: {
          logo_url: string | null
          organization_id: string
          primary_color: string
          public_name: string
          updated_at: string
          updated_by: string
        }
        Insert: {
          logo_url?: string | null
          organization_id: string
          primary_color?: string
          public_name: string
          updated_at?: string
          updated_by: string
        }
        Update: {
          logo_url?: string | null
          organization_id?: string
          primary_color?: string
          public_name?: string
          updated_at?: string
          updated_by?: string
        }
        Relationships: [
          {
            foreignKeyName: "organization_branding_organization_id_fkey"
            columns: ["organization_id"]
            isOneToOne: true
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "organization_branding_updated_by_fkey"
            columns: ["updated_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      organization_drive_configs: {
        Row: {
          connected_at: string | null
          connected_by: string | null
          organization_id: string
          root_folder_id: string | null
          status: Database["public"]["Enums"]["drive_connection_status"]
          updated_at: string
        }
        Insert: {
          connected_at?: string | null
          connected_by?: string | null
          organization_id: string
          root_folder_id?: string | null
          status?: Database["public"]["Enums"]["drive_connection_status"]
          updated_at?: string
        }
        Update: {
          connected_at?: string | null
          connected_by?: string | null
          organization_id?: string
          root_folder_id?: string | null
          status?: Database["public"]["Enums"]["drive_connection_status"]
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "organization_drive_configs_connected_by_fkey"
            columns: ["connected_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "organization_drive_configs_organization_id_fkey"
            columns: ["organization_id"]
            isOneToOne: true
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
        ]
      }
      organizations: {
        Row: {
          created_at: string
          created_by: string
          id: string
          name: string
          slug: string
          updated_at: string
        }
        Insert: {
          created_at?: string
          created_by: string
          id?: string
          name: string
          slug: string
          updated_at?: string
        }
        Update: {
          created_at?: string
          created_by?: string
          id?: string
          name?: string
          slug?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "organizations_created_by_fkey"
            columns: ["created_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      patient_consents: {
        Row: {
          consent_type: string
          created_at: string
          document_version: string
          granted_at: string
          id: string
          notes: string | null
          organization_id: string
          patient_id: string
          recorded_by: string
          revoked_at: string | null
        }
        Insert: {
          consent_type: string
          created_at?: string
          document_version: string
          granted_at?: string
          id?: string
          notes?: string | null
          organization_id: string
          patient_id: string
          recorded_by: string
          revoked_at?: string | null
        }
        Update: {
          consent_type?: string
          created_at?: string
          document_version?: string
          granted_at?: string
          id?: string
          notes?: string | null
          organization_id?: string
          patient_id?: string
          recorded_by?: string
          revoked_at?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "patient_consents_organization_id_fkey"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "patient_consents_patient_tenant_fkey"
            columns: ["patient_id", "organization_id"]
            isOneToOne: false
            referencedRelation: "patients"
            referencedColumns: ["id", "organization_id"]
          },
          {
            foreignKeyName: "patient_consents_recorded_by_fkey"
            columns: ["recorded_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      patient_content_deliveries: {
        Row: {
          content_version_id: string
          delivered_at: string
          delivered_by: string
          id: string
          organization_id: string
          patient_id: string
          snapshot: Json
        }
        Insert: {
          content_version_id: string
          delivered_at?: string
          delivered_by: string
          id?: string
          organization_id: string
          patient_id: string
          snapshot: Json
        }
        Update: {
          content_version_id?: string
          delivered_at?: string
          delivered_by?: string
          id?: string
          organization_id?: string
          patient_id?: string
          snapshot?: Json
        }
        Relationships: [
          {
            foreignKeyName: "patient_content_deliveries_content_version_id_fkey"
            columns: ["content_version_id"]
            isOneToOne: false
            referencedRelation: "content_library_versions"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "patient_content_deliveries_delivered_by_fkey"
            columns: ["delivered_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "patient_content_deliveries_organization_id_fkey"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "patient_content_deliveries_patient_tenant_fkey"
            columns: ["patient_id", "organization_id"]
            isOneToOne: false
            referencedRelation: "patients"
            referencedColumns: ["id", "organization_id"]
          },
        ]
      }
      patient_goals: {
        Row: {
          active: boolean
          created_at: string
          created_by: string
          ends_on: string | null
          id: string
          kind: Database["public"]["Enums"]["patient_goal_kind"]
          organization_id: string
          patient_id: string
          starts_on: string
          target_unit: string | null
          target_value: number | null
          title: string
        }
        Insert: {
          active?: boolean
          created_at?: string
          created_by: string
          ends_on?: string | null
          id?: string
          kind: Database["public"]["Enums"]["patient_goal_kind"]
          organization_id: string
          patient_id: string
          starts_on?: string
          target_unit?: string | null
          target_value?: number | null
          title: string
        }
        Update: {
          active?: boolean
          created_at?: string
          created_by?: string
          ends_on?: string | null
          id?: string
          kind?: Database["public"]["Enums"]["patient_goal_kind"]
          organization_id?: string
          patient_id?: string
          starts_on?: string
          target_unit?: string | null
          target_value?: number | null
          title?: string
        }
        Relationships: [
          {
            foreignKeyName: "patient_goals_created_by_fkey"
            columns: ["created_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "patient_goals_organization_id_fkey"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "patient_goals_patient_tenant_fkey"
            columns: ["patient_id", "organization_id"]
            isOneToOne: false
            referencedRelation: "patients"
            referencedColumns: ["id", "organization_id"]
          },
        ]
      }
      patient_guardians: {
        Row: {
          can_manage_appointments: boolean
          can_view_plan: boolean
          created_at: string
          guardian_user_id: string
          id: string
          organization_id: string
          patient_id: string
          relationship: string
        }
        Insert: {
          can_manage_appointments?: boolean
          can_view_plan?: boolean
          created_at?: string
          guardian_user_id: string
          id?: string
          organization_id: string
          patient_id: string
          relationship: string
        }
        Update: {
          can_manage_appointments?: boolean
          can_view_plan?: boolean
          created_at?: string
          guardian_user_id?: string
          id?: string
          organization_id?: string
          patient_id?: string
          relationship?: string
        }
        Relationships: [
          {
            foreignKeyName: "patient_guardians_guardian_user_id_fkey"
            columns: ["guardian_user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "patient_guardians_organization_id_fkey"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "patient_guardians_patient_tenant_fkey"
            columns: ["patient_id", "organization_id"]
            isOneToOne: false
            referencedRelation: "patients"
            referencedColumns: ["id", "organization_id"]
          },
        ]
      }
      patient_water_logs: {
        Row: {
          amount_ml: number
          created_at: string
          created_by: string
          id: string
          occurred_on: string
          organization_id: string
          patient_id: string
          updated_at: string
        }
        Insert: {
          amount_ml: number
          created_at?: string
          created_by: string
          id?: string
          occurred_on?: string
          organization_id: string
          patient_id: string
          updated_at?: string
        }
        Update: {
          amount_ml?: number
          created_at?: string
          created_by?: string
          id?: string
          occurred_on?: string
          organization_id?: string
          patient_id?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "patient_water_logs_created_by_fkey"
            columns: ["created_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "patient_water_logs_organization_id_fkey"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "patient_water_logs_patient_tenant_fkey"
            columns: ["patient_id", "organization_id"]
            isOneToOne: false
            referencedRelation: "patients"
            referencedColumns: ["id", "organization_id"]
          },
        ]
      }
      patients: {
        Row: {
          anonymous_code: string
          birth_date: string | null
          created_at: string
          created_by: string
          email: string | null
          full_name: string
          id: string
          organization_id: string
          patient_user_id: string | null
          phone: string | null
          professional_id: string
          status: string
          updated_at: string
        }
        Insert: {
          anonymous_code: string
          birth_date?: string | null
          created_at?: string
          created_by: string
          email?: string | null
          full_name: string
          id?: string
          organization_id: string
          patient_user_id?: string | null
          phone?: string | null
          professional_id: string
          status?: string
          updated_at?: string
        }
        Update: {
          anonymous_code?: string
          birth_date?: string | null
          created_at?: string
          created_by?: string
          email?: string | null
          full_name?: string
          id?: string
          organization_id?: string
          patient_user_id?: string | null
          phone?: string | null
          professional_id?: string
          status?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "patients_created_by_fkey"
            columns: ["created_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "patients_organization_id_fkey"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "patients_patient_user_id_fkey"
            columns: ["patient_user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "patients_professional_id_fkey"
            columns: ["professional_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      plan_days: {
        Row: {
          day_index: number
          id: string
          kind: Database["public"]["Enums"]["day_kind"]
          label: string
          organization_id: string
          plan_version_id: string
          weekday: number | null
        }
        Insert: {
          day_index: number
          id?: string
          kind?: Database["public"]["Enums"]["day_kind"]
          label: string
          organization_id: string
          plan_version_id: string
          weekday?: number | null
        }
        Update: {
          day_index?: number
          id?: string
          kind?: Database["public"]["Enums"]["day_kind"]
          label?: string
          organization_id?: string
          plan_version_id?: string
          weekday?: number | null
        }
        Relationships: [
          {
            foreignKeyName: "plan_days_organization_id_fkey"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "plan_days_plan_version_id_organization_id_fkey"
            columns: ["plan_version_id", "organization_id"]
            isOneToOne: false
            referencedRelation: "plan_versions"
            referencedColumns: ["id", "organization_id"]
          },
        ]
      }
      plan_templates: {
        Row: {
          catalog_key: string | null
          created_at: string
          created_by: string
          dimensions: Json
          id: string
          name: string
          objective: string | null
          organization_id: string
          rules: Json
          scope: Database["public"]["Enums"]["plan_template_scope"]
          snapshot: Json
          source_plan_id: string | null
          tags: string[]
          updated_at: string
        }
        Insert: {
          catalog_key?: string | null
          created_at?: string
          created_by: string
          dimensions?: Json
          id?: string
          name: string
          objective?: string | null
          organization_id: string
          rules?: Json
          scope?: Database["public"]["Enums"]["plan_template_scope"]
          snapshot: Json
          source_plan_id?: string | null
          tags?: string[]
          updated_at?: string
        }
        Update: {
          catalog_key?: string | null
          created_at?: string
          created_by?: string
          dimensions?: Json
          id?: string
          name?: string
          objective?: string | null
          organization_id?: string
          rules?: Json
          scope?: Database["public"]["Enums"]["plan_template_scope"]
          snapshot?: Json
          source_plan_id?: string | null
          tags?: string[]
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "plan_templates_created_by_fkey"
            columns: ["created_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "plan_templates_organization_id_fkey"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "plan_templates_source_plan_id_fkey"
            columns: ["source_plan_id"]
            isOneToOne: false
            referencedRelation: "plans"
            referencedColumns: ["id"]
          },
        ]
      }
      plan_versions: {
        Row: {
          ai_generated: boolean
          assistant_state: Json
          change_summary: string | null
          content_hash: string | null
          created_at: string
          created_by: string
          id: string
          locked_at: string | null
          organization_id: string
          plan_id: string
          published_at: string | null
          reviewed_at: string | null
          reviewed_by: string | null
          targets: Json
          version_no: number
        }
        Insert: {
          ai_generated?: boolean
          assistant_state?: Json
          change_summary?: string | null
          content_hash?: string | null
          created_at?: string
          created_by: string
          id?: string
          locked_at?: string | null
          organization_id: string
          plan_id: string
          published_at?: string | null
          reviewed_at?: string | null
          reviewed_by?: string | null
          targets?: Json
          version_no: number
        }
        Update: {
          ai_generated?: boolean
          assistant_state?: Json
          change_summary?: string | null
          content_hash?: string | null
          created_at?: string
          created_by?: string
          id?: string
          locked_at?: string | null
          organization_id?: string
          plan_id?: string
          published_at?: string | null
          reviewed_at?: string | null
          reviewed_by?: string | null
          targets?: Json
          version_no?: number
        }
        Relationships: [
          {
            foreignKeyName: "plan_versions_created_by_fkey"
            columns: ["created_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "plan_versions_organization_id_fkey"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "plan_versions_plan_id_organization_id_fkey"
            columns: ["plan_id", "organization_id"]
            isOneToOne: false
            referencedRelation: "plans"
            referencedColumns: ["id", "organization_id"]
          },
          {
            foreignKeyName: "plan_versions_reviewed_by_fkey"
            columns: ["reviewed_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      plans: {
        Row: {
          created_at: string
          created_by: string
          current_published_version_id: string | null
          ends_on: string | null
          id: string
          organization_id: string
          patient_id: string
          published_at: string | null
          published_by: string | null
          reviewed_at: string | null
          reviewed_by: string | null
          starts_on: string | null
          status: Database["public"]["Enums"]["plan_status"]
          title: string
          updated_at: string
        }
        Insert: {
          created_at?: string
          created_by: string
          current_published_version_id?: string | null
          ends_on?: string | null
          id?: string
          organization_id: string
          patient_id: string
          published_at?: string | null
          published_by?: string | null
          reviewed_at?: string | null
          reviewed_by?: string | null
          starts_on?: string | null
          status?: Database["public"]["Enums"]["plan_status"]
          title?: string
          updated_at?: string
        }
        Update: {
          created_at?: string
          created_by?: string
          current_published_version_id?: string | null
          ends_on?: string | null
          id?: string
          organization_id?: string
          patient_id?: string
          published_at?: string | null
          published_by?: string | null
          reviewed_at?: string | null
          reviewed_by?: string | null
          starts_on?: string | null
          status?: Database["public"]["Enums"]["plan_status"]
          title?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "plans_created_by_fkey"
            columns: ["created_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "plans_current_version_tenant_fkey"
            columns: ["current_published_version_id", "organization_id"]
            isOneToOne: false
            referencedRelation: "plan_versions"
            referencedColumns: ["id", "organization_id"]
          },
          {
            foreignKeyName: "plans_organization_id_fkey"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "plans_patient_id_organization_id_fkey"
            columns: ["patient_id", "organization_id"]
            isOneToOne: false
            referencedRelation: "patients"
            referencedColumns: ["id", "organization_id"]
          },
          {
            foreignKeyName: "plans_published_by_fkey"
            columns: ["published_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "plans_reviewed_by_fkey"
            columns: ["reviewed_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      profiles: {
        Row: {
          created_at: string
          display_name: string | null
          full_name: string
          id: string
          updated_at: string
        }
        Insert: {
          created_at?: string
          display_name?: string | null
          full_name: string
          id: string
          updated_at?: string
        }
        Update: {
          created_at?: string
          display_name?: string | null
          full_name?: string
          id?: string
          updated_at?: string
        }
        Relationships: []
      }
      rooms: {
        Row: {
          active: boolean
          created_at: string
          id: string
          name: string
          organization_id: string
        }
        Insert: {
          active?: boolean
          created_at?: string
          id?: string
          name: string
          organization_id: string
        }
        Update: {
          active?: boolean
          created_at?: string
          id?: string
          name?: string
          organization_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "rooms_organization_id_fkey"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
        ]
      }
      substitution_requests: {
        Row: {
          created_at: string
          id: string
          meal_item_id: string
          organization_id: string
          patient_id: string
          patient_note: string | null
          plan_version_id: string
          professional_note: string | null
          requested_by: string
          reviewed_at: string | null
          reviewed_by: string | null
          status: Database["public"]["Enums"]["substitution_request_status"]
          substitution_id: string
          updated_at: string
        }
        Insert: {
          created_at?: string
          id?: string
          meal_item_id: string
          organization_id: string
          patient_id: string
          patient_note?: string | null
          plan_version_id: string
          professional_note?: string | null
          requested_by: string
          reviewed_at?: string | null
          reviewed_by?: string | null
          status?: Database["public"]["Enums"]["substitution_request_status"]
          substitution_id: string
          updated_at?: string
        }
        Update: {
          created_at?: string
          id?: string
          meal_item_id?: string
          organization_id?: string
          patient_id?: string
          patient_note?: string | null
          plan_version_id?: string
          professional_note?: string | null
          requested_by?: string
          reviewed_at?: string | null
          reviewed_by?: string | null
          status?: Database["public"]["Enums"]["substitution_request_status"]
          substitution_id?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "substitution_requests_meal_item_id_organization_id_fkey"
            columns: ["meal_item_id", "organization_id"]
            isOneToOne: false
            referencedRelation: "meal_items"
            referencedColumns: ["id", "organization_id"]
          },
          {
            foreignKeyName: "substitution_requests_organization_id_fkey"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "substitution_requests_patient_id_organization_id_fkey"
            columns: ["patient_id", "organization_id"]
            isOneToOne: false
            referencedRelation: "patients"
            referencedColumns: ["id", "organization_id"]
          },
          {
            foreignKeyName: "substitution_requests_plan_version_id_organization_id_fkey"
            columns: ["plan_version_id", "organization_id"]
            isOneToOne: false
            referencedRelation: "plan_versions"
            referencedColumns: ["id", "organization_id"]
          },
          {
            foreignKeyName: "substitution_requests_requested_by_fkey"
            columns: ["requested_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "substitution_requests_reviewed_by_fkey"
            columns: ["reviewed_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "substitution_requests_substitution_id_organization_id_fkey"
            columns: ["substitution_id", "organization_id"]
            isOneToOne: false
            referencedRelation: "meal_item_substitutions"
            referencedColumns: ["id", "organization_id"]
          },
        ]
      }
    }
    Views: {
      follow_up_queue: {
        Row: {
          checkin_id: string | null
          detected_at: string | null
          id: string | null
          kind: Database["public"]["Enums"]["alert_kind"] | null
          message: string | null
          organization_id: string | null
          patient_id: string | null
          patient_name: string | null
          priority_score: number | null
          severity: Database["public"]["Enums"]["alert_severity"] | null
          status: Database["public"]["Enums"]["alert_status"] | null
        }
        Relationships: [
          {
            foreignKeyName: "adherence_alerts_checkin_id_organization_id_fkey"
            columns: ["checkin_id", "organization_id"]
            isOneToOne: false
            referencedRelation: "meal_checkins"
            referencedColumns: ["id", "organization_id"]
          },
          {
            foreignKeyName: "adherence_alerts_organization_id_fkey"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "adherence_alerts_patient_id_organization_id_fkey"
            columns: ["patient_id", "organization_id"]
            isOneToOne: false
            referencedRelation: "patients"
            referencedColumns: ["id", "organization_id"]
          },
        ]
      }
    }
    Functions: {
      apply_plan_template_to_patient: {
        Args: { target_patient_id: string; target_template_id: string }
        Returns: {
          created_at: string
          created_by: string
          current_published_version_id: string | null
          ends_on: string | null
          id: string
          organization_id: string
          patient_id: string
          published_at: string | null
          published_by: string | null
          reviewed_at: string | null
          reviewed_by: string | null
          starts_on: string | null
          status: Database["public"]["Enums"]["plan_status"]
          title: string
          updated_at: string
        }
        SetofOptions: {
          from: "*"
          to: "plans"
          isOneToOne: true
          isSetofReturn: false
        }
      }
      audit_clinical_export: {
        Args: { target_kind: string; target_patient_id: string }
        Returns: undefined
      }
      bootstrap_organization: {
        Args: {
          full_name_input: string
          organization_name_input: string
          organization_slug_input: string
        }
        Returns: string
      }
      cancel_appointment: {
        Args: { reason: string; target_id: string }
        Returns: undefined
      }
      claim_patient_access: { Args: never; Returns: string[] }
      copy_plan_template_to_patient: {
        Args: { target_patient_id: string; target_template_id: string }
        Returns: {
          created_at: string
          created_by: string
          current_published_version_id: string | null
          ends_on: string | null
          id: string
          organization_id: string
          patient_id: string
          published_at: string | null
          published_by: string | null
          reviewed_at: string | null
          reviewed_by: string | null
          starts_on: string | null
          status: Database["public"]["Enums"]["plan_status"]
          title: string
          updated_at: string
        }
        SetofOptions: {
          from: "*"
          to: "plans"
          isOneToOne: true
          isSetofReturn: false
        }
      }
      create_follow_up_action: {
        Args: {
          target_action: string
          target_alert_id: string
          target_note?: string
        }
        Returns: {
          action_type: string
          alert_id: string
          created_at: string
          created_by: string
          id: string
          note: string | null
          organization_id: string
          patient_id: string
        }
        SetofOptions: {
          from: "*"
          to: "follow_up_actions"
          isOneToOne: true
          isSetofReturn: false
        }
      }
      create_plan_template_from_plan: {
        Args: {
          target_name: string
          target_objective?: string
          target_plan_id: string
          target_tags?: string[]
        }
        Returns: {
          catalog_key: string | null
          created_at: string
          created_by: string
          dimensions: Json
          id: string
          name: string
          objective: string | null
          organization_id: string
          rules: Json
          scope: Database["public"]["Enums"]["plan_template_scope"]
          snapshot: Json
          source_plan_id: string | null
          tags: string[]
          updated_at: string
        }
        SetofOptions: {
          from: "*"
          to: "plan_templates"
          isOneToOne: true
          isSetofReturn: false
        }
      }
      create_plan_template_from_plan_v2: {
        Args: {
          target_dimensions?: Json
          target_name: string
          target_plan_id: string
          target_rules?: Json
          target_scope?: Database["public"]["Enums"]["plan_template_scope"]
        }
        Returns: {
          catalog_key: string | null
          created_at: string
          created_by: string
          dimensions: Json
          id: string
          name: string
          objective: string | null
          organization_id: string
          rules: Json
          scope: Database["public"]["Enums"]["plan_template_scope"]
          snapshot: Json
          source_plan_id: string | null
          tags: string[]
          updated_at: string
        }
        SetofOptions: {
          from: "*"
          to: "plan_templates"
          isOneToOne: true
          isSetofReturn: false
        }
      }
      deliver_content_to_patient: {
        Args: { target_patient_id: string; target_version_id: string }
        Returns: {
          content_version_id: string
          delivered_at: string
          delivered_by: string
          id: string
          organization_id: string
          patient_id: string
          snapshot: Json
        }
        SetofOptions: {
          from: "*"
          to: "patient_content_deliveries"
          isOneToOne: true
          isSetofReturn: false
        }
      }
      get_current_shopping_list: {
        Args: { target_days?: number; target_patient_id: string }
        Returns: {
          description: string
          item_key: string
          occurrences: number
          total_grams: number
        }[]
      }
      get_patient_drive_status: {
        Args: { target_patient_id: string }
        Returns: {
          can_upload_photos: boolean
          status: Database["public"]["Enums"]["drive_connection_status"]
        }[]
      }
      get_patient_weekly_summary: {
        Args: { target_days?: number; target_patient_id: string }
        Returns: Json
      }
      has_organization_role: {
        Args: {
          allowed_roles: Database["public"]["Enums"]["organization_role"][]
          target_organization_id: string
        }
        Returns: boolean
      }
      import_catalog_foods: {
        Args: {
          target_items: Json
          target_organization_id: string
          target_source_id: string
        }
        Returns: {
          id: string
          name: string
        }[]
      }
      is_active_member: {
        Args: { target_organization_id: string }
        Returns: boolean
      }
      publish_content_library_version: {
        Args: { target_body: string; target_item_id: string }
        Returns: {
          body: string
          id: string
          item_id: string
          organization_id: string
          published_at: string
          published_by: string
          title: string
          version_no: number
        }
        SetofOptions: {
          from: "*"
          to: "content_library_versions"
          isOneToOne: true
          isSetofReturn: false
        }
      }
      publish_plan_version: {
        Args: { target_plan_id: string; target_version_id: string }
        Returns: undefined
      }
      review_appointment: {
        Args: {
          target_id: string
          target_meeting_url?: string
          target_staff_note?: string
          target_status: Database["public"]["Enums"]["appointment_status"]
        }
        Returns: undefined
      }
      review_clinical_draft: {
        Args: {
          target_draft_id: string
          target_status: Database["public"]["Enums"]["clinical_draft_status"]
        }
        Returns: {
          body: string
          created_at: string
          created_by: string
          id: string
          kind: Database["public"]["Enums"]["clinical_draft_kind"]
          organization_id: string
          patient_id: string
          provider: string
          reviewed_at: string | null
          reviewed_by: string | null
          source_snapshot: Json
          status: Database["public"]["Enums"]["clinical_draft_status"]
        }
        SetofOptions: {
          from: "*"
          to: "clinical_drafts"
          isOneToOne: true
          isSetofReturn: false
        }
      }
      review_plan_version: {
        Args: {
          target_assistant_state?: Json
          target_plan_id: string
          target_targets?: Json
          target_version_id: string
        }
        Returns: undefined
      }
      review_substitution_request: {
        Args: {
          target_note?: string
          target_request_id: string
          target_status: Database["public"]["Enums"]["substitution_request_status"]
        }
        Returns: {
          created_at: string
          id: string
          meal_item_id: string
          organization_id: string
          patient_id: string
          patient_note: string | null
          plan_version_id: string
          professional_note: string | null
          requested_by: string
          reviewed_at: string | null
          reviewed_by: string | null
          status: Database["public"]["Enums"]["substitution_request_status"]
          substitution_id: string
          updated_at: string
        }
        SetofOptions: {
          from: "*"
          to: "substitution_requests"
          isOneToOne: true
          isSetofReturn: false
        }
      }
      save_form_response: {
        Args: {
          target_assignment_id: string
          target_submit?: boolean
          target_values: Json
        }
        Returns: {
          assignment_id: string
          created_by: string
          id: string
          organization_id: string
          patient_id: string
          status: Database["public"]["Enums"]["form_assignment_status"]
          submitted_at: string | null
          updated_at: string
          values: Json
          version_id: string
        }
        SetofOptions: {
          from: "*"
          to: "form_responses"
          isOneToOne: true
          isSetofReturn: false
        }
      }
      seed_practicas_dieteticas: {
        Args: { target_created_by?: string; target_organization_id: string }
        Returns: undefined
      }
      update_alert_status: {
        Args: {
          target_id: string
          target_status: Database["public"]["Enums"]["alert_status"]
        }
        Returns: undefined
      }
    }
    Enums: {
      alert_kind:
        | "allergy_or_reaction"
        | "severe_symptom"
        | "low_intake"
        | "intense_hunger"
        | "rapid_weight_change"
        | "other"
      alert_severity: "info" | "attention" | "urgent"
      alert_status: "open" | "acknowledged" | "resolved"
      appointment_modality: "in_person" | "online" | "home_visit"
      appointment_status:
        | "requested"
        | "approved"
        | "rejected"
        | "cancelled"
        | "completed"
        | "no_show"
      catalog_kind: "food" | "preparation" | "combination"
      checkin_state: "completed" | "adapted" | "skipped"
      clinical_draft_kind: "summary" | "guidance" | "plan_structure"
      clinical_draft_status: "draft" | "approved" | "discarded"
      day_kind:
        | "standard"
        | "training"
        | "rest"
        | "shift"
        | "weekend"
        | "custom"
      drive_connection_status: "missing" | "connected"
      form_assignment_status: "pending" | "draft" | "submitted"
      form_field_type:
        | "short_text"
        | "long_text"
        | "number"
        | "scale"
        | "select"
        | "date"
      membership_status: "invited" | "active" | "suspended"
      organization_role:
        | "owner"
        | "admin"
        | "nutritionist"
        | "student"
        | "receptionist"
      patient_goal_kind: "water" | "meals" | "weight" | "behavior"
      plan_status:
        | "draft"
        | "in_review"
        | "reviewed"
        | "approved"
        | "scheduled"
        | "published"
        | "superseded"
        | "archived"
      plan_template_scope: "personal" | "organization"
      substitution_request_status:
        | "requested"
        | "approved"
        | "rejected"
        | "cancelled"
    }
    CompositeTypes: {
      [_ in never]: never
    }
  }
}

type DatabaseWithoutInternals = Omit<Database, "__InternalSupabase">

type DefaultSchema = DatabaseWithoutInternals[Extract<keyof Database, "public">]

export type Tables<
  DefaultSchemaTableNameOrOptions extends
    | keyof (DefaultSchema["Tables"] & DefaultSchema["Views"])
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"] &
        DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Views"])
    : never = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"] &
      DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Views"])[TableName] extends {
      Row: infer R
    }
    ? R
    : never
  : DefaultSchemaTableNameOrOptions extends keyof (DefaultSchema["Tables"] &
        DefaultSchema["Views"])
    ? (DefaultSchema["Tables"] &
        DefaultSchema["Views"])[DefaultSchemaTableNameOrOptions] extends {
        Row: infer R
      }
      ? R
      : never
    : never

export type TablesInsert<
  DefaultSchemaTableNameOrOptions extends
    | keyof DefaultSchema["Tables"]
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"][TableName] extends {
      Insert: infer I
    }
    ? I
    : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema["Tables"]
    ? DefaultSchema["Tables"][DefaultSchemaTableNameOrOptions] extends {
        Insert: infer I
      }
      ? I
      : never
    : never

export type TablesUpdate<
  DefaultSchemaTableNameOrOptions extends
    | keyof DefaultSchema["Tables"]
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"][TableName] extends {
      Update: infer U
    }
    ? U
    : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema["Tables"]
    ? DefaultSchema["Tables"][DefaultSchemaTableNameOrOptions] extends {
        Update: infer U
      }
      ? U
      : never
    : never

export type Enums<
  DefaultSchemaEnumNameOrOptions extends
    | keyof DefaultSchema["Enums"]
    | { schema: keyof DatabaseWithoutInternals },
  EnumName extends DefaultSchemaEnumNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"]
    : never = never,
> = DefaultSchemaEnumNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"][EnumName]
  : DefaultSchemaEnumNameOrOptions extends keyof DefaultSchema["Enums"]
    ? DefaultSchema["Enums"][DefaultSchemaEnumNameOrOptions]
    : never

export type CompositeTypes<
  PublicCompositeTypeNameOrOptions extends
    | keyof DefaultSchema["CompositeTypes"]
    | { schema: keyof DatabaseWithoutInternals },
  CompositeTypeName extends PublicCompositeTypeNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"]
    : never = never,
> = PublicCompositeTypeNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"][CompositeTypeName]
  : PublicCompositeTypeNameOrOptions extends keyof DefaultSchema["CompositeTypes"]
    ? DefaultSchema["CompositeTypes"][PublicCompositeTypeNameOrOptions]
    : never

export const Constants = {
  public: {
    Enums: {
      alert_kind: [
        "allergy_or_reaction",
        "severe_symptom",
        "low_intake",
        "intense_hunger",
        "rapid_weight_change",
        "other",
      ],
      alert_severity: ["info", "attention", "urgent"],
      alert_status: ["open", "acknowledged", "resolved"],
      appointment_modality: ["in_person", "online", "home_visit"],
      appointment_status: [
        "requested",
        "approved",
        "rejected",
        "cancelled",
        "completed",
        "no_show",
      ],
      catalog_kind: ["food", "preparation", "combination"],
      checkin_state: ["completed", "adapted", "skipped"],
      clinical_draft_kind: ["summary", "guidance", "plan_structure"],
      clinical_draft_status: ["draft", "approved", "discarded"],
      day_kind: ["standard", "training", "rest", "shift", "weekend", "custom"],
      drive_connection_status: ["missing", "connected"],
      form_assignment_status: ["pending", "draft", "submitted"],
      form_field_type: [
        "short_text",
        "long_text",
        "number",
        "scale",
        "select",
        "date",
      ],
      membership_status: ["invited", "active", "suspended"],
      organization_role: [
        "owner",
        "admin",
        "nutritionist",
        "student",
        "receptionist",
      ],
      patient_goal_kind: ["water", "meals", "weight", "behavior"],
      plan_status: [
        "draft",
        "in_review",
        "reviewed",
        "approved",
        "scheduled",
        "published",
        "superseded",
        "archived",
      ],
      plan_template_scope: ["personal", "organization"],
      substitution_request_status: [
        "requested",
        "approved",
        "rejected",
        "cancelled",
      ],
    },
  },
} as const
