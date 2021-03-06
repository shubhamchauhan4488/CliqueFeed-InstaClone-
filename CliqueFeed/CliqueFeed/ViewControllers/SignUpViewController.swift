//
//  SignUpViewController.swift
//  CliqueFeed
//
//  Created by SHUBHAM  CHAUHAN on 16/03/18.
//  Copyright © 2018 shubhamchauhan. All rights reserved.
//

import UIKit
import FirebaseDatabase
import FirebaseStorage
import FirebaseAuth
import FirebaseCore
import SkyFloatingLabelTextField

class SignUpViewController: UIViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    
    @IBOutlet weak var passwordHintLbl: UILabel!
    @IBOutlet weak var profileImage: UIImageView!
    @IBOutlet weak var name: SkyFloatingLabelTextField!
    @IBOutlet weak var email: SkyFloatingLabelTextField!
    @IBOutlet weak var password: SkyFloatingLabelTextField!
    @IBOutlet weak var confirmPassword: SkyFloatingLabelTextField!
    @IBOutlet weak var nxtBtn: UIButton!
    let picker = UIImagePickerController()
    var userStorage : StorageReference!
    var databaseRef : DatabaseReference!
    var uploadedImageUrlString = String()
    let indicator = UIActivityIndicatorView()
    typealias onFirebaseUploadComplete = () -> ()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        indicator.hidesWhenStopped = true
        indicator.center = view.center
        indicator.activityIndicatorViewStyle = UIActivityIndicatorViewStyle.whiteLarge
        view.addSubview(indicator)
        
        passwordHintLbl.isHidden = true
        picker.delegate = self
        let storage = Storage.storage().reference(forURL: "gs://cliquefeed-48d9c.appspot.com")
        userStorage = storage.child("users")
        databaseRef = Database.database().reference()
    }
    
    @IBAction func onEmailTextChanged(_ sender: Any) {
        
        if email.isEditing{
            if let text = email.text {
                if(text.count < 3 || !(text.contains("@")) || !(text.contains(".com"))) {
                    email.errorMessage = "Invalid Email"
                }
                else {
                    // The error message will only disappear when we reset it to nil or empty string
                    email.errorMessage = ""
                }
            }
        }
        if email.text == "" {
            email.errorMessage = ""
        }
    }
    
    @IBAction func onNameTextChanged(_ sender: Any) {
        
        if name.isEditing{
            if let text = name.text {
                if(text.count < 2 ) {
                    name.errorMessage = "Enter more than one character"
                }
                else {
                    // The error message will only disappear when we reset it to nil or empty string
                    name.errorMessage = ""
                }
            }
        }
        
        if name.text == "" {
            name.errorMessage = ""
        }
    }
    
    @IBAction func onPasswordTextChanged(_ sender: Any) {
        if let passwordtext = password.text {
            let passwordTest = NSPredicate(format: "SELF MATCHES %@", "^(?=.*[a-z])(?=.*[$@$#!%*?&])[A-Za-z\\d$@$#!%*?&]{8,}")
            if !(passwordTest.evaluate(with: passwordtext)){
                password.errorMessage = "Invalid Password"
                passwordHintLbl.isHidden = false
            }
            else {
                password.errorMessage = ""
                passwordHintLbl.isHidden = true
            }
        }
        
        if password.text == "" {
            password.errorMessage = ""
        }
    }
    @IBAction func onConfirmPasswordTextChanged(_ sender: Any) {
        
        if let confirmPasssword = confirmPassword.text {
            if (confirmPasssword != password.text!) {
                confirmPassword.errorMessage = "Passwords donot match"
            }
            else{
                confirmPassword.errorMessage = ""
            }
        }
        
        if confirmPassword.text == "" {
            confirmPassword.errorMessage = ""
        }
    }
    
    @IBAction func onImageSelect(_ sender: UIButton) {
        picker.allowsEditing = true
        picker.sourceType = .photoLibrary
        present(picker, animated: true, completion: nil)
    }
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : Any]) {
        if let image = info[UIImagePickerControllerEditedImage] as? UIImage
        {
            self.profileImage.image = image
            self.nxtBtn.isHidden = false
        }
        self.dismiss(animated: true, completion: nil)
    }
    
    @IBAction func onNextPress(_ sender: UIButton) {
        //checking if any field is empty
        if ( name.text != "" && email.text != "" && password.text != "" && confirmPassword.text != "" && profileImage.image != UIImage(named: "cam"))
        {
            //checking if passwords entered match
            if(password.text == confirmPassword.text && confirmPassword.errorMessage == "" && password.errorMessage == "" && name.errorMessage == "")
            {
                //Creating user via firebase
                Auth.auth().createUser(withEmail: email.text!, password: password.text!, completion: { (user, error) in
                    
                    //catching the error
                    if let error = error
                    {
                        let alert = UIAlertController(title: "Account creation failure", message: error.localizedDescription, preferredStyle: .actionSheet)
                        let okAction = UIAlertAction(title: "Ok", style: .default, handler: nil)
                        alert.addAction(okAction)
                        self.present(alert, animated: true)
                    }
                    
                    //If user is successfully created on firebase
                    if let user = user
                    {
                        self.nxtBtn.isEnabled = false
                        UIApplication.shared.beginIgnoringInteractionEvents()
                        let imageRef = self.userStorage.child("\(user.user.uid).jpg")
                        //Downgrading the image selected by the user and putting in 'data' variable
                        let data = UIImageJPEGRepresentation(self.profileImage.image!, 0.5 )
                        
                        self.indicator.startAnimating()
                        //Putting the image on the 'unique' reference created on Firebase inside Users folder
                        let uploadTask = imageRef.putData(data!, metadata: nil, completion: { (metadata, err) in
                            if let err = err {
                                let alert = UIAlertController(title: "Account creation failure", message: err.localizedDescription, preferredStyle: .actionSheet)
                                let okAction = UIAlertAction(title: "Ok", style: .default, handler: nil)
                                alert.addAction(okAction)
                                self.present(alert, animated: true)
                            }
                            imageRef.downloadURL(completion: { (url, er) in
                                if let er = er {
                                    let alert = UIAlertController(title: "Account creation failure", message: er.localizedDescription, preferredStyle: .actionSheet)
                                    let okAction = UIAlertAction(title: "Ok", style: .default, handler: nil)
                                    alert.addAction(okAction)
                                    self.present(alert, animated: true)
                                }
                                
                                if let url = url{
                                    self.uploadedImageUrlString = url.absoluteString
                                    self.uploadUserToFirebase{
                                        self.nxtBtn.isEnabled = true
                                        self.indicator.stopAnimating()
                                        UIApplication.shared.endIgnoringInteractionEvents()
                                        let alert = UIAlertController(title: "Successfull", message: "Account successfully created! Login Now", preferredStyle: .actionSheet)
                                        let okAction = UIAlertAction(title: "OK", style: .default) { (alertAction) in
                                            
                                            self.navigationController?.popToRootViewController(animated: true)
                                        }
                                        alert.addAction(okAction)
                                        self.present(alert, animated: true)
                                    }
                                }
                                
                            })
                        })
                        uploadTask.resume()
                    }
                })
            }
            else{
                let alert = UIAlertController(title: "Account creation failure", message: "Please fix errors", preferredStyle: .actionSheet)
                let okAction = UIAlertAction(title: "Ok", style: .default, handler: nil)
                alert.addAction(okAction)
                self.present(alert, animated: true)
            }
        }
        else
        {
            let alert = UIAlertController(title: "Account creation failure", message: "All details Mandatory", preferredStyle: .actionSheet)
            let okAction = UIAlertAction(title: "Ok", style: .default, handler: nil)
            alert.addAction(okAction)
            self.present(alert, animated: true)
        }
        
        
    }
    
    func uploadUserToFirebase(completion : @escaping onFirebaseUploadComplete){
        
        //Creating postInfo object and saving to Firebase
        let userInfo : [String:Any] = ["uid": Auth.auth().currentUser!.uid,
                                       "name" : name.text!,
                                       "email" : email.text!,
                                       "password" : password.text!,
                                       "urlImage": uploadedImageUrlString]
        
        
        self.databaseRef.child("users").child(Auth.auth().currentUser!.uid).setValue(userInfo)
        completion()
    }
    
    @IBAction func onLoginPress(_ sender: Any) {
        self.navigationController?.popToRootViewController(animated: true)
    }
    
    
    
}
