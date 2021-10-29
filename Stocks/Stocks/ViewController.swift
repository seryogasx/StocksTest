//
//  ViewController.swift
//  Stocks
//
//  Created by Сергей Петров on 03.09.2021.
//

import UIKit

class ViewController: UIViewController {

    @IBOutlet weak var companyNameButton: UIButton!
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    @IBOutlet weak var priceLabel: UILabel!
    @IBOutlet weak var companySymbolLabel: UILabel!
    @IBOutlet weak var priceChangeLabel: UILabel!
    @IBOutlet weak var stockLogoImageView: UIImageView!
    @IBOutlet weak var imageHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var priceHeaderLabel: UILabel!
    @IBOutlet weak var priceChangeHeaderLabel: UIStackView!
    
    
    let tableView = UITableView()
    let cellIdentifier = "StockCell"
    let cellHeight: CGFloat = 50
    
    private var session: URLSession!
    
    
    private var selectedCompanySymbol: String?
    private var companies: [String: String] = [:]
    
    let overlayView = UIView()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(UINib(nibName: "StockCell", bundle: nil), forCellReuseIdentifier: cellIdentifier)
        
        self.priceLabel.isHidden = true
        self.companySymbolLabel.isHidden = true
        self.priceChangeLabel.isHidden = true
        self.stockLogoImageView.isHidden = true
        self.priceHeaderLabel.isHidden = true
        self.priceChangeHeaderLabel.isHidden = true
        
        self.companyNameButton.layer.cornerRadius = 15
        self.companyNameButton.layer.backgroundColor = CGColor(gray: 0.5, alpha: 0.2)
        
        self.stockLogoImageView.contentMode = .scaleAspectFit
        
        let config = URLSessionConfiguration.default
        config.waitsForConnectivity = true
        config.timeoutIntervalForRequest = 5
        config.timeoutIntervalForResource = 5
        
        session = URLSession(configuration: config, delegate: nil, delegateQueue: nil)
        
        self.getCompanies()
        self.activityIndicator.hidesWhenStopped = true
    }
    
    override func viewDidAppear(_ animated: Bool) {
        if companies.count < 0 {
            getCompanies()
        }
    }
}


//MARK: UI operations
extension ViewController {
    
    private func showAlert(title: String, message: String, actions: [UIAlertAction] = []) {
        DispatchQueue.main.async { [weak self] in
            let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
            for action in actions {
                alert.addAction(action)
            }
            self?.show(alert, sender: nil)
        }
    }
    
    private func stopActivityAnimating() {
        DispatchQueue.main.async { [weak self] in
            self?.activityIndicator.stopAnimating()
        }
    }
    
    private func displayStockInfo(companyName: String, symbol: String, price: Double, priceChange: Double, changePercent: Double, currency: String) {
        self.activityIndicator.stopAnimating()
        self.companyNameButton.setTitle(companyName, for: .normal)
        self.companySymbolLabel.text = "Ticker: \(symbol)"
        self.priceLabel.text = "\(price) \(currency)"
        self.priceChangeLabel.text = "\(priceChange) (\(changePercent)%)"
        
        self.priceLabel.isHidden = false
        self.companySymbolLabel.isHidden = false
        self.priceChangeLabel.isHidden = false
        self.priceHeaderLabel.isHidden = false
        self.priceChangeHeaderLabel.isHidden = false
        
        self.priceChangeLabel.textColor = abs(changePercent) < 0.01 ? .black : changePercent > 0 ? .green : .red
    }
    
    private func requestQuoteUpdate() {
        self.activityIndicator.startAnimating()
        if !self.stockLogoImageView.isHidden {
            self.hideLogo()
        }
        self.companyNameButton.setTitle("---", for: .normal)
        self.companySymbolLabel.text = "---"
        self.priceLabel.text = "---"
        self.priceChangeLabel.text = "---"
        self.priceChangeLabel.textColor = .black
        
        self.requestQuote(for: self.selectedCompanySymbol!)
    }
    
    private func hideLogo() {
        DispatchQueue.main.async { [weak self] in
            self?.stockLogoImageView.alpha = 1
            UIView.animate(withDuration: 0.25) {
                self?.stockLogoImageView.isHidden = true
                self?.stockLogoImageView.alpha = 0
            }
        }
    }
    
    private func showLogo() {
        DispatchQueue.main.async { [weak self] in
            self?.stockLogoImageView.alpha = 0
            UIView.animate(withDuration: 0.25) {
                self?.stockLogoImageView.isHidden = false
                self?.stockLogoImageView.alpha = 1
            }
        }
    }
}


//MARK: Network operations
extension ViewController {
    
    private func getCompanies() {
        let url = URL(string: "https://cloud.iexapis.com/stable/stock/market/list/mostactive?token=\(UserDefaults.standard.value(forKey: "token")!)")!
        self.activityIndicator.startAnimating()
        session.dataTask(with: url) { [weak self] (data, response, error) in
            guard error == nil, (response as? HTTPURLResponse)?.statusCode == 200, let data = data
            else {
                self?.showAlert(title: "No internet", message: "Retrying every 5 seconds")
                self?.stopActivityAnimating()
                DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) { [weak self] in
                    self?.getCompanies()
                }
                return
            }

            do {
                let jsonObject = try JSONSerialization.jsonObject(with: data)
                guard let json = jsonObject as? [Any]
                else {
                    print("Invalid JSON format! Cannot get companies!")
                    self?.showAlert(title: "Unknown error", message: "Something goes wrong! Please, try later!")
                    self?.stopActivityAnimating()
                    return
                }

                for i in json {
                    guard let companyName = (i as? [String: Any])?["companyName"] as? String,
                          let companySymbol = (i as? [String: Any])?["symbol"] as? String
                    else { print("Cannot take symbols!"); return }
                    self?.companies[companyName] = companySymbol
                }
                DispatchQueue.main.async { [weak self] in
                    self?.tableView.reloadData()
                    self?.stopActivityAnimating()
                }
            } catch {
                print("JSON parsing error! \(error.localizedDescription)")
                self?.showAlert(title: "Unknown error", message: "Something goes wrong! Please, try later!")
                self?.stopActivityAnimating()
            }
        }.resume()
    }

    private func requestQuote(for symbol: String) {
        let url = URL(string: "https://cloud.iexapis.com/stable/stock/\(symbol)/quote?token=\(UserDefaults.standard.value(forKey: "token")!)")!
        self.activityIndicator.startAnimating()
        session.dataTask(with: url) { [weak self] (data, response, error) in
            guard error == nil, (response as? HTTPURLResponse)?.statusCode == 200, let data = data
            else {
                print("Network error detected!")
                self?.showAlert(title: "Bad internet", message: "Retrying every 5 seconds")
                DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) { [weak self] in
                    self?.requestQuote(for: symbol)
                }
                self?.stopActivityAnimating()
                return
            }
            self?.getImageQuote(symbol: symbol)
            self?.parseQuote(data: data)
        }.resume()
    }
    
    private func getImageQuote(symbol: String) {
        let url = URL(string: "https://cloud.iexapis.com/stable/stock/\(symbol)/logo?token=\(UserDefaults.standard.value(forKey: "token")!)")!
        session.dataTask(with: url) { [weak self] (data, response, error) in
            guard error == nil, (response as? HTTPURLResponse)?.statusCode == 200, let data = data
            else {
                print("Network error detected! Cannot get logo!")
                self?.showAlert(title: "Network error", message: "Network error detected! Cannot get logo!")
                self?.stopActivityAnimating()
                return
            }
            do {
                let jsonObject = try JSONSerialization.jsonObject(with: data)
                guard let json = jsonObject as? [String: Any], let logoUrlString = json["url"] as? String
                else {
                    print("Invalid JSON format! Cannot get stock logo!")
                    self?.showAlert(title: "Unknown error", message: "Something goes wrong! Please, try later!")
                    self?.stopActivityAnimating()
                    return
                }
                guard let logoUrl = URL(string: logoUrlString) else {
                    print("No logo for stock!")
                    DispatchQueue.main.async { [weak self] in
                        if let image = UIImage(named: "defaultLogo") {
                            self?.stockLogoImageView.image = image
                            self?.showLogo()
                            self?.imageHeightConstraint.constant = min(image.size.height, UIScreen.main.bounds.height / 4)
                            self?.stopActivityAnimating()
                        } else {
                            self?.hideLogo()
                        }
                    }
                    return
                }
                self?.session.dataTask(with: logoUrl) { [weak self] (data, response, error) in
                    guard error == nil, (response as? HTTPURLResponse)?.statusCode == 200, let data = data
                    else {
                        print("Cannot get image!")
                        self?.stopActivityAnimating()
                        return
                    }
                    
                    DispatchQueue.main.async { [weak self] in
                        if let image = UIImage(data: data) {
                            self?.stockLogoImageView.image = image
                            self?.showLogo()
                            self?.imageHeightConstraint.constant = min(image.size.height, UIScreen.main.bounds.height / 4)
                            self?.stopActivityAnimating()
                        } else {
                            self?.hideLogo()
                        }
                    }
                }.resume()
            } catch {
                print("JSON parsing error! Cannot take stock logo! \(error.localizedDescription)")
                self?.showAlert(title: "Unknown error", message: "Something goes wrong! Please, try later!")
                self?.stopActivityAnimating()
            }
        }.resume()
    }

    private func parseQuote(data: Data) {
        do {
            let jsonObject = try JSONSerialization.jsonObject(with: data)
            guard let json = jsonObject as? [String: Any],
                  let companyName = json["companyName"] as? String,
                  let companySymbol = json["symbol"] as? String,
                  let price = json["latestPrice"] as? Double,
                  let priceChange = json["change"] as? Double,
                  let changePercent = json["changePercent"] as? Double,
                  let currency = json["currency"] as? String
            else {
                print("Invalid JSON format!")
                self.showAlert(title: "Unknown error", message: "Something goes wrong! Please, try later!")
                self.stopActivityAnimating()
                return
            }
            DispatchQueue.main.async { [weak self] in
                self?.displayStockInfo(companyName: companyName, symbol: companySymbol, price: price, priceChange: priceChange, changePercent: changePercent, currency: currency)
                self?.stopActivityAnimating()
            }
        } catch {
            print("JSON parsing error: \(error.localizedDescription)")
            self.showAlert(title: "Unknown error", message: "Something goes wrong! Please, try later!")
            self.stopActivityAnimating()
        }
    }
}


//MARK: TableViewSettings
extension ViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return companies.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: cellIdentifier, for: indexPath) as! StockCell
        cell.setup(title: Array(self.companies.keys)[indexPath.row], symbol: Array(self.companies.values)[indexPath.row])
        return cell
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        cellHeight
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let symbol = Array(self.companies.values)[indexPath.row]
        if self.selectedCompanySymbol != symbol {
            self.selectedCompanySymbol = symbol
            self.requestQuoteUpdate()
            removeTransparentView(baseFrame: self.companyNameButton.frame)
        }
    }
}


//MARK: TableView animation settings
extension ViewController {
    
    func addOverlayView(baseFrame: CGRect) {
        overlayView.frame = self.view.frame
        overlayView.backgroundColor = UIColor.black
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(removeTransparentView))
        overlayView.addGestureRecognizer(tapGesture)
        overlayView.alpha = 0
        self.view.addSubview(overlayView)
        
        tableView.frame = CGRect(x: baseFrame.origin.x, y: baseFrame.origin.y + baseFrame.height + 50, width: baseFrame.width, height: 0)
        self.view.addSubview(tableView)
        
        UIView.animate(withDuration: 0.4, delay: 0.0, usingSpringWithDamping: 1.0, initialSpringVelocity: 1.0, options: .curveEaseOut, animations: {
            let maxTableViewHeight = min(CGFloat(self.companies.count) * self.cellHeight, UIScreen.main.bounds.height - (baseFrame.origin.y + baseFrame.height + 50))
            self.tableView.frame = CGRect(x: baseFrame.origin.x, y: baseFrame.origin.y + baseFrame.height + 50, width: baseFrame.width, height: maxTableViewHeight)
            self.overlayView.alpha = 0.5
        }, completion: nil)
    }
    
    @IBAction func companyNameButtonClicked(_ sender: Any) {
        addOverlayView(baseFrame: companyNameButton.frame)
    }
    
    @objc private func removeTransparentView(baseFrame: CGRect) {
        UIView.animate(withDuration: 0.4, delay: 0.0, usingSpringWithDamping: 1.0, initialSpringVelocity: 1.0, options: .curveEaseIn, animations: {
            self.tableView.frame = CGRect(x: baseFrame.origin.x, y: baseFrame.origin.y + baseFrame.height + 50, width: baseFrame.width, height: 0)
            self.overlayView.alpha = 0
        }, completion: nil)
    }
}
