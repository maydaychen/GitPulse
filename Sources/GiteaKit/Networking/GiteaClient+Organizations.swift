import Foundation

extension GiteaClient {
    private struct OrganizationDTO: Decodable {
        let id: Int
        let username: String?
        let name: String?
        let fullName: String?
    }

    /// Fetch organizations accessible by the authenticated user.
    public func fetchUserOrganizations(limit: Int = 50) async throws -> [OrganizationSummary] {
        let dtos: [OrganizationDTO] = try await fetchJSON(
            endpoint: "/user/orgs",
            queryItems: [
                URLQueryItem(name: "page", value: "1"),
                URLQueryItem(name: "limit", value: "\(limit)")
            ]
        )
        var seen = Set<String>()
        return dtos.compactMap { dto in
            let slug = ((dto.username?.isEmpty == false ? dto.username : nil) ?? dto.name ?? "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !slug.isEmpty, seen.insert(slug.lowercased()).inserted else { return nil }
            let display = (dto.fullName ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            return OrganizationSummary(id: "\(dto.id)", username: slug, fullName: display)
        }
    }

    /// Fetch repositories owned by a specific organization.
    public func fetchOrganizationRepositories(
        org: String,
        page: Int = 1,
        limit: Int = 50,
        currentUsername: String? = nil
    ) async throws -> [RepositorySummary] {
        let encodedOrg = GiteaURLBuilder.encodedSegment(org)
        let dtos: [RepoDTO] = try await fetchJSON(
            endpoint: "/orgs/\(encodedOrg)/repos",
            queryItems: [
                URLQueryItem(name: "page", value: "\(page)"),
                URLQueryItem(name: "limit", value: "\(limit)")
            ]
        )
        return dtos.map { dto in
            var summary = dto.toRepositorySummary(currentUsername: currentUsername)
            summary.isOrganizationOwned = true
            if !summary.isMirror {
                summary.scope = .org
            }
            return summary
        }
    }

    /// Reconcile existing repositories against known organizations and fetch missing org repos.
    public func mergeOrganizationRepositories(
        organizations: [OrganizationSummary],
        into repositories: [RepositorySummary],
        currentUsername: String? = nil,
        maxPagesPerOrg: Int = 2
    ) async -> [RepositorySummary] {
        let orgKeys = Set(
            organizations
                .map { $0.username.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
                .filter { !$0.isEmpty }
        )
        var merged = repositories
        var seenIDs = Set<String>()

        for index in merged.indices {
            seenIDs.insert(merged[index].id)
            let ownerKey = merged[index].owner.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            if orgKeys.contains(ownerKey) {
                merged[index].isOrganizationOwned = true
                if !merged[index].isMirror {
                    merged[index].scope = .org
                }
            }
        }

        guard maxPagesPerOrg > 0 else {
            return Self.stableSortRepositories(merged)
        }

        let pageSize = 50
        for org in organizations.prefix(12) {
            for page in 1...maxPagesPerOrg {
                guard let batch = try? await fetchOrganizationRepositories(
                    org: org.username,
                    page: page,
                    limit: pageSize,
                    currentUsername: currentUsername
                ) else { break }

                for repo in batch {
                    if seenIDs.insert(repo.id).inserted {
                        merged.append(repo)
                    } else if let idx = merged.firstIndex(where: { $0.id == repo.id }) {
                        merged[idx].isOrganizationOwned = true
                        if !merged[idx].isMirror {
                            merged[idx].scope = .org
                        }
                    }
                }
                if batch.count < pageSize { break }
            }
        }

        return Self.stableSortRepositories(merged)
    }

    private static func stableSortRepositories(_ repositories: [RepositorySummary]) -> [RepositorySummary] {
        repositories
            .enumerated()
            .sorted { lhs, rhs in
                if lhs.element.updatedAtText != rhs.element.updatedAtText {
                    return lhs.element.updatedAtText > rhs.element.updatedAtText
                }
                return lhs.offset < rhs.offset
            }
            .map(\.element)
    }
}
