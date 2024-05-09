//
//  ViewController.swift
//  CombineTest
//
//  Created by MadCow on 2024/5/8.
//

import UIKit
import Combine

class ViewController: UIViewController {
    
    private var videoInfos: [(String, String, String, String)] = []
    
    private let searchField: UITextField = {
        let tf = UITextField()
        tf.translatesAutoresizingMaskIntoConstraints = false
        tf.placeholder = "Search Text"
        tf.text = "침착맨"
        
        return tf
    }()
    
    private let searchButton: UIButton = {
        let btn = UIButton()
        btn.translatesAutoresizingMaskIntoConstraints = false
        btn.backgroundColor = .blue
        btn.setTitle("검색", for: .normal)
        btn.tintColor = .white
        btn.layer.borderWidth = 1
        btn.layer.cornerRadius = 10
        
        return btn
    }()
    
    private let tableView: UITableView = {
        let table = UITableView()
        table.translatesAutoresizingMaskIntoConstraints = false
        
        return table
    }()
    
    var cancellables = Set<AnyCancellable>()
    private var page: Int = 1
        
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.addSubview(searchField)
        view.addSubview(searchButton)
        view.addSubview(tableView)
        
        searchButton.addTarget(self, action: #selector(searchVideo), for: .touchUpInside)
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(ViewCell.self, forCellReuseIdentifier: "ViewCell")
        
        NSLayoutConstraint.activate([
            searchField.topAnchor.constraint(equalTo: view.topAnchor, constant: 80),
            searchField.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 10),
            
            searchButton.centerYAnchor.constraint(equalTo: searchField.centerYAnchor),
            searchButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -10),
            searchButton.widthAnchor.constraint(equalToConstant: 100),
            searchButton.heightAnchor.constraint(equalTo: searchButton.heightAnchor),
            
            tableView.topAnchor.constraint(equalTo: searchButton.bottomAnchor, constant: 5),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
    
    @objc func searchVideo() {
        guard let searchText = self.searchField.text else { return }
        self.videoInfos = []
        self.page = 1
        test(searchText: searchText, page: page)
    }
    
    func test(searchText: String, page: Int) {
        loadVideos(text: searchText, page: page).sink { completion in
            switch completion {
            case .finished:
                print("End!")
            case .failure(let error):
                print("error! > \(error.localizedDescription)")
            }
        } receiveValue: { videoInfo in
            DispatchQueue.main.async {
                self.videoInfos += videoInfo
                self.tableView.reloadData()
            }
        }.store(in: &cancellables)
    }
    
    func loadVideos(text: String, page: Int) -> Future<[(String, String, String, String)], Error> {
        return Future { futureResponse in
            let endpoint = "https://dapi.kakao.com/v2/search/vclip?query=\(text)&&sort=recency&&page=\(page)&&size=10"
            let apiKey = "e2bbe272dc60ca8f0be0dd419334a2e9"
            var request = URLRequest(url: URL(string: endpoint)!)
            request.httpMethod = "GET"
            request.setValue("KakaoAK \(apiKey)", forHTTPHeaderField: "Authorization")
            
            URLSession.shared.dataTask(with: request) { (data, response, error) in
                if let error = error {
                    print("Error: \(error)")
                    return
                }
                
                guard let data = data else {
                    print("No data received")
                    return
                }
                
                do {
                    let json = try JSONSerialization.jsonObject(with: data, options: []) as! [String: Any]
                    if let clips = json["documents"] as? [[String: Any]] {
                        var responseArr: [(String, String, String, String)] = []
                        for clip in clips {
                            let title = clip["title"] as! String
                            let url = clip["url"] as! String
                            let thumbnail = clip["thumbnail"] as! String
                            let author = clip["author"] as! String
                            
                            responseArr.append((title, url, thumbnail, author))
                        }
                        futureResponse(.success(responseArr))
                    }
                } catch {
                    print("error after task > \(error.localizedDescription)")
                    futureResponse(.failure(error))
                }
            }.resume()
        }
    }
}

extension ViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.videoInfos.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "ViewCell", for: indexPath) as? ViewCell else { return UITableViewCell()}
        
        let info = videoInfos[indexPath.item]
        if let imageUrl = URL(string: info.2) {
            DispatchQueue.global().async {
                if let imageData = try? Data(contentsOf: imageUrl) {
                    if let image = UIImage(data: imageData) {
                        DispatchQueue.main.async {
                            cell.testImage.image = image
                        }
                    }
                }
            }
        }
        cell.titleTextField.text = info.0
        return cell
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 100
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if let url = URL(string: videoInfos[indexPath.item].1) {
            UIApplication.shared.open(url)
        }
        
//        let viewController = VideoPlayView()
//        viewController.videoUrlString = videoInfos[indexPath.item].1
//        navigationController?.pushViewController(viewController, animated: true)
//        present(viewController, animated: true, completion: nil)
    }
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        let offsetY = scrollView.contentOffset.y
        let contentHeight = scrollView.contentSize.height
        
        if offsetY > contentHeight - scrollView.frame.height {
            self.page += 1
            guard let searchText = self.searchField.text else { return }
            test(searchText: searchText, page: page)
        }
    }
}
