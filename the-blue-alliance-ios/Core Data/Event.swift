//
//  Event.swift
//  the-blue-alliance
//
//  Created by Zach Orr on 1/7/17.
//  Copyright © 2017 The Blue Alliance. All rights reserved.
//

import Foundation
import TBAKit
import CoreData

public enum EventType: Int {
    case regional = 0
    case district = 1
    case districtChampionship = 2
    case championshipDivision = 3
    case championshipFinals = 4
    case districtChampionshipDivision = 5
    case offseason = 99
    case preseason = 100
    case unlabeled = -1
}

enum InitError: Error {
    case invalid(key: String)
}

extension Event {

    var divisionKeys: [String] {
        get {
            return divisionKeysArray as? Array<String> ?? []
        }
        set {
            divisionKeysArray = newValue as NSArray
        }
    }
    
    static func insert(with model: TBAEvent, in context: NSManagedObjectContext) throws -> Event {
        let predicate = NSPredicate(format: "key == %@", model.key)
        
        let fetchRequest: NSFetchRequest<Event> = Event.fetchRequest()
        fetchRequest.predicate = predicate
        fetchRequest.fetchLimit = 1
        fetchRequest.returnsObjectsAsFaults = false
        
        let events = try fetchRequest.execute()
        let event = events.first ?? Event(context: context)
        
        // Required: endDate, eventCode, eventType, key, name, startDate, year
        event.address = model.address
        event.city = model.city
        event.country = model.country
        
        if let district = model.district {
            event.district = try? District.insert(with: district, in: context)
        }

        // TODO: Let's see if we can get a background task or something to go through and form relationships...
        if !model.divisionKeys.isEmpty {
            event.divisionKeys = model.divisionKeys
        }
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        
        guard let endDate = dateFormatter.date(from: model.endDate) else {
            context.delete(event)
            throw InitError.invalid(key: "endDate")
        }
        
        event.endDate = NSDate(timeIntervalSince1970: endDate.timeIntervalSince1970)
        
        event.eventCode = model.eventCode
        event.eventType = Int16(model.eventType)
        event.eventTypeName = model.eventTypeName
        event.firstEventID = model.firstEventID
        event.gmapsPlaceID = model.gmapsPlaceID
        event.gmapsURL = model.gmapsURL
        event.key = model.key
        
        if let lat = model.lat {
            event.lat = NSNumber(value: lat)
        }
        if let lng = model.lng {
            event.lng = NSNumber(value: lng)
        }
        
        event.locationName = model.locationName
        event.name = model.name
        
        // TODO: Can we convert this to a relationship?
        event.parentEventKey = model.parentEventKey
        if let playoffType = model.playoffType {
            event.playoffType = Int16(playoffType)
        }
        event.playoffTypeString = model.playoffTypeString
        
        event.postalCode = model.postalCode
        event.shortName = model.shortName
        
        guard let startDate = dateFormatter.date(from: model.startDate) else {
            context.delete(event)
            throw InitError.invalid(key: "startDate")
        }
        event.startDate = NSDate(timeIntervalSince1970: startDate.timeIntervalSince1970)
        
        event.state = model.state
        event.timezone = model.timezone
        
        if let webcasts = model.webcasts {
            for modelWebcast in webcasts {
                _ = try? Webcast.insert(with: modelWebcast, for: event, in: context)
            }
        }
        
        event.website = model.website
        
        if let week = model.week {
            event.week = NSNumber(integerLiteral: week)
        }
        
        event.year = Int16(model.year)
                
        return event
    }
        
    public func dateString() -> String? {
        if self.startDate == nil || self.endDate == nil {
            return nil
        }
        
        let calendar = Calendar.current
        
        let shortDateFormatter = DateFormatter()
        shortDateFormatter.dateFormat = "MMM dd"
        
        let longDateFormatter = DateFormatter()
        longDateFormatter.dateFormat = "MMM dd, y"
        
        let startDate = Date(timeIntervalSince1970: self.startDate!.timeIntervalSince1970)
        let endDate = Date(timeIntervalSince1970: self.endDate!.timeIntervalSince1970)
        
        if let timezone = timezone {
            let tz = TimeZone(identifier: timezone)
            shortDateFormatter.timeZone = tz
            longDateFormatter.timeZone = tz
        }
        
        var dateText: String?
        if startDate == endDate {
            dateText = longDateFormatter.string(from: Date(timeIntervalSince1970: endDate.timeIntervalSince1970))
        } else if calendar.component(.year, from: startDate) == calendar.component(.year, from: endDate) {
            dateText = "\(shortDateFormatter.string(from: startDate)) to \(shortDateFormatter.string(from: endDate))"
        } else {
            dateText = "\(longDateFormatter.string(from: startDate)) to \(longDateFormatter.string(from: endDate))"
        }
        
        return dateText
    }
    
    public var weekString: String {
        var weekString = "nil"
        let eventType = Int(self.eventType)
        if eventType == EventType.championshipDivision.rawValue || eventType == EventType.championshipFinals.rawValue {
            // TODO: Need to handle different CMPs - "FIRST Championship - Houston" and "FIRST Championship - St. Louis"
            if year >= 2017, let city = city {
                weekString = "Championship - \(city)"
            } else {
                weekString = "Championship"
            }
        } else {
            switch eventType {
            case EventType.unlabeled.rawValue:
                weekString = "Other"
            case EventType.preseason.rawValue:
                weekString = "Preseason"
            case EventType.offseason.rawValue:
                weekString = "Offseason"
            default:
                guard let week = week else {
                    return "Other"
                }
                
                /**
                 * Special cases for 2016:
                 * Week 1 is actually Week 0.5, eveything else is one less
                 * See http://www.usfirst.org/roboticsprograms/frc/blog-The-Palmetto-Regional
                 */
                if year == 2016 {
                    if week == 0 {
                        weekString = "Week 0.5"
                    } else {
                        weekString = "Week \(week.intValue)"
                    }
                } else {
                    weekString = "Week \(week.intValue + 1)"
                }
            }
        }
        return weekString
    }
    
    public var friendlyNameWithYear: String {
        let nameString = shortName ?? name
        return "\(String(year)) \(nameString ?? "Unnamed") \(eventTypeName ?? "Event")"
    }
    
    public var isChampionship: Bool {
        let type = Int(eventType)
        return type == EventType.championshipDivision.rawValue || type == EventType.championshipFinals.rawValue
    }
    
    public var isDistrictChampionship: Bool {
        let type = Int(eventType)
        return type == EventType.districtChampionshipDivision.rawValue || type == EventType.districtChampionship.rawValue
    }
}

extension Event: Comparable {
    
    // MARK: Comparable
    
    // In order... Preseason, Week 1, Week 2, ..., Week 7, CMP, Offseason, Unlabeled
    // (type: 100, week: nil) < (type: 0, week: 1)
    // (type: 99, week: nil) < (type: -1, week: nil)
    
    public static func <(lhs: Event, rhs: Event) -> Bool {
        if lhs.year != rhs.year {
            return lhs.year < rhs.year
        }
        
        let lhsType = Int(lhs.eventType)
        let rhsType = Int(rhs.eventType)
        
        // Preseason events should always come first
        if lhsType == EventType.preseason.rawValue || rhsType == EventType.preseason.rawValue {
            // Preseason, being 100, has the highest event type. So even though this seems backwards... it's not
            return lhsType > rhsType
        }
        // Unlabeled events go at the very end no matter what
        if lhsType == EventType.unlabeled.rawValue || rhsType == EventType.unlabeled.rawValue {
            // Same as preseason - unlabeled events are the lowest possible number so even though this line seems backwards it's not
            return lhsType > rhsType
        }
        // Offseason events come after everything besides unlabeled
        if lhsType == EventType.offseason.rawValue || rhsType == EventType.offseason.rawValue {
            // We've already handled preseason (100) so now we can assume offseason's (99) will always be the highest type
            return lhsType < rhsType
        }
        // CMP finals come after everything besides offseason, unlabeled
        if lhsType == EventType.championshipFinals.rawValue || rhsType == EventType.championshipFinals.rawValue {
            // Make sure we handle that districtCMPDivision case
            if lhsType == EventType.districtChampionshipDivision.rawValue || rhsType == EventType.districtChampionshipDivision.rawValue {
                return lhsType > rhsType
            } else {
                return lhsType < rhsType
            }
        }
        // CMP divisions are next
        if lhsType == EventType.championshipDivision.rawValue || rhsType == EventType.championshipDivision.rawValue {
            // Make sure we handle that districtCMPDivision case
            if lhsType == EventType.districtChampionshipDivision.rawValue || rhsType == EventType.districtChampionshipDivision.rawValue {
                return lhsType > rhsType
            } else {
                return lhsType < rhsType
            }
        }
        // EVERYTHING ELSE (districts, regionals, DCMPs, DCMP divisions) has weeks. This is just an easy sort... which event has a first week
        // Only weird thing is how we're sorting events that have the same weeks. It goes...
        // Regional < District < DCMP Division < DCMP
        if let lhsWeek = lhs.week, let rhsWeek = rhs.week {
            if lhsWeek == rhsWeek {
                // Make sure we handle the weird case of district championship divisions being a higher number than DCMPs
                if (lhsType == EventType.districtChampionshipDivision.rawValue || rhsType == EventType.districtChampionshipDivision.rawValue) &&
                    (lhsType == EventType.districtChampionship.rawValue || rhsType == EventType.districtChampionship.rawValue) {
                    return lhsType > rhsType
                } else {
                    return lhsType < rhsType
                }
            } else {
                return lhsWeek.intValue < rhsWeek.intValue
            }
        }
        return false
    }
    
}
