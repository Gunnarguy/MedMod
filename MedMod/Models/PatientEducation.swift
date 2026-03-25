import Foundation

/// Static patient education resource links mapped to diagnoses and ICD-10 codes
enum PatientEducation {
    struct EducationLink {
        let title: String
        let description: String
        let icon: String
    }

    static func links(for condition: String, icd10: String? = nil) -> [EducationLink] {
        var results: [EducationLink] = []
        let lower = condition.lowercased()

        // Skin cancer
        if lower.contains("basal cell") || lower.contains("bcc") || icd10?.hasPrefix("C44") == true {
            results.append(EducationLink(title: "Basal Cell Carcinoma", description: "AAD: Causes, treatment options, and prevention strategies", icon: "cross.case"))
            results.append(EducationLink(title: "Sun Protection Guide", description: "SPF 30+ daily, reapply every 2 hours during exposure", icon: "sun.max.trianglebadge.exclamationmark"))
        }

        if lower.contains("melanoma") || icd10?.hasPrefix("D03") == true || icd10?.hasPrefix("C43") == true {
            results.append(EducationLink(title: "Melanoma Awareness", description: "ABCDE rule for self-exams — Asymmetry, Border, Color, Diameter, Evolution", icon: "eye"))
            results.append(EducationLink(title: "Post-Excision Care", description: "Wound care, activity restrictions, and follow-up schedule", icon: "bandage"))
            results.append(EducationLink(title: "Skin Self-Exam Guide", description: "Monthly full-body skin checks — what to look for", icon: "figure.stand"))
        }

        if lower.contains("dysplastic nevus") || lower.contains("atypical") || icd10?.hasPrefix("D22") == true {
            results.append(EducationLink(title: "Atypical Moles", description: "Understanding dysplastic nevi and surveillance recommendations", icon: "magnifyingglass"))
            results.append(EducationLink(title: "Monthly Self-Exam", description: "Monitor all moles for ABCDE changes between visits", icon: "figure.stand"))
        }

        // Actinic keratosis
        if lower.contains("actinic") || icd10 == "L57.0" {
            results.append(EducationLink(title: "Actinic Keratosis", description: "Precancerous lesions — treatment options and prevention", icon: "sun.max"))
            results.append(EducationLink(title: "Cryotherapy Aftercare", description: "Expect blistering and redness; apply petrolatum 2–3x daily", icon: "snowflake"))
        }

        // Acne
        if lower.contains("acne") || icd10?.hasPrefix("L70") == true {
            results.append(EducationLink(title: "Acne Treatment Guide", description: "Retinoids, benzoyl peroxide, and oral antibiotics — what to expect", icon: "face.smiling"))
            results.append(EducationLink(title: "Tretinoin Counseling", description: "Apply pea-sized amount at night; expect purging phase weeks 2–6", icon: "moon.stars"))
        }

        // Rosacea
        if lower.contains("rosacea") || icd10?.hasPrefix("L71") == true {
            results.append(EducationLink(title: "Rosacea Triggers", description: "Avoid sun, heat, alcohol, spicy foods — keep a trigger diary", icon: "thermometer.sun"))
            results.append(EducationLink(title: "Rosacea Treatment", description: "Topical ivermectin, azelaic acid, and lifestyle modifications", icon: "drop"))
        }

        // Eczema / Atopic dermatitis
        if lower.contains("eczema") || lower.contains("atopic dermatitis") || icd10?.hasPrefix("L20") == true {
            results.append(EducationLink(title: "Eczema Management", description: "Moisturize within 3 minutes of bathing — soak and smear technique", icon: "humidity"))
            results.append(EducationLink(title: "Steroid Application", description: "Fingertip units guide — proper amount and duration for each body area", icon: "hand.point.up"))
            results.append(EducationLink(title: "Dupixent Patient Guide", description: "Injection technique, storage, and common side effects", icon: "syringe"))
        }

        // Contact dermatitis
        if lower.contains("contact dermatitis") || icd10?.hasPrefix("L23") == true || icd10?.hasPrefix("L24") == true {
            results.append(EducationLink(title: "Contact Dermatitis", description: "Identify and avoid allergens — patch testing explained", icon: "hand.raised"))
            results.append(EducationLink(title: "Nickel Allergy", description: "Common sources: jewelry, belt buckles, watchbands, snaps", icon: "exclamationmark.shield"))
        }

        // Psoriasis
        if lower.contains("psoriasis") || icd10?.hasPrefix("L40") == true {
            results.append(EducationLink(title: "Psoriasis Overview", description: "Chronic autoimmune condition — triggers, treatment ladder, and lifestyle", icon: "sparkles"))
            results.append(EducationLink(title: "Methotrexate Guide", description: "Take once weekly — avoid alcohol, monitor labs regularly", icon: "pills"))
            results.append(EducationLink(title: "Psoriatic Arthritis", description: "Joint stiffness warning signs and when to see rheumatology", icon: "figure.walk"))
        }

        // Warts
        if lower.contains("verruca") || lower.contains("wart") || icd10?.hasPrefix("B07") == true {
            results.append(EducationLink(title: "Wart Treatment", description: "Cryotherapy, imiquimod, and salicylic acid — what to expect", icon: "snowflake"))
            results.append(EducationLink(title: "HPV Prevention", description: "Handwashing, avoid picking, and vaccination information", icon: "hand.raised"))
        }

        // Generic — always show sun protection for derm patients
        if results.isEmpty {
            results.append(EducationLink(title: "Skin Health Basics", description: "Daily SPF 30+, annual skin exams, and self-monitoring tips", icon: "sun.max"))
        }

        return results
    }
}
